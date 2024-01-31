from threading import Thread, Event
from queue import Queue
import time
import numpy as np
import traceback

# This code originally used Process not Thread.
# Process is much slower to start (Process.start() is ~100 ms, Thread.start() is a few ms)
# The process-safe versions of Queue and Event are also significantly slower.
# On the other hand, CPU-bound Python threads can't run in parallel ("global interpreter lock").
# The overall problem is not CPU-bound - we should always be limited by tProc execution.
# In the worst case where the tProc is running fast, we should actually be waiting for IO a lot (due to the DMA).
# So we think it's safe to use threads.
# However, this is a complicated problem and we may ultimately need to mess around with sys.setswitchinterval() or go back to Process.
# To use Process instead of Thread, use the following import and change WORKERTYPE.
#from multiprocessing import Process, Queue, Event

class DataStreamer():
    """
    Uses a separate thread to read data from the average buffers.
    The class methods define the readout loop and initialization of the worker thread.
    The QickSoc methods start_readout() and poll_data() are the external interface to the streamer.

    We don't lock the QickSoc or the IPs. The user is responsible for not disrupting a readout in progress.

    :param soc: The QickSoc object.
    :type soc: QickSoc
    """

    #WORKERTYPE = Process
    WORKERTYPE = Thread

    def __init__(self, soc):
        self.soc = soc

        self.start_worker()

    def start_worker(self):
        # Initialize flags and queues.
        # Passes run commands from the main thread to the worker thread.
        self.job_queue = Queue()
        # Passes data from the worker thread to the main thread.
        self.data_queue = Queue()
        # Passes exceptions from the worker thread to the main thread.
        self.error_queue = Queue()
        # The main thread can use this flag to tell the worker thread to stop.
        # The main thread clears the flag when starting readout.
        self.stop_flag = Event()
        # The worker thread uses this to tell the main thread when it's done.
        # The main thread clears the flag when starting readout.
        self.done_flag = Event()
        self.done_flag.set()

        # Process object for the streaming readout.
        # daemon=True means the readout thread will be killed if the parent is killed
        self.readout_worker = self.WORKERTYPE(target=self._run_readout, daemon=True)
        self.readout_worker.start()

    def stop_readout(self):
        """
        Signal the readout loop to break.
        """
        self.stop_flag.set()

    def readout_running(self):
        """
        Test if the readout loop is running.

        :return: readout thread status
        :rtype: bool
        """
        return not self.done_flag.is_set()

    def data_available(self):
        """
        Test if data is available in the queue.

        :return: data queue status
        :rtype: bool
        """
        return not self.data_queue.empty()

    def _run_readout(self):
        """
        Worker thread for the streaming readout

        :param total_count: Number of data points expected
        :type addr: int
        :param counter_addr: Data memory address for the loop counter
        :type counter_addr: int
        :param ch_list: List of readout channels
        :type addr: list of int
        :param reads_per_count: Number of data points to expect per counter increment
        :type reads_per_count: list of int
        """
        while True:
            try:
                # wait for a job
                total_shots, counter_addr, ch_list, reads_per_count, stride = self.job_queue.get(block=True)
                #print("streamer loop: start", total_count)

                shots = 0
                last_shots = 0

                # how many shots worth of data to transfer at a time
                if stride is None:
                    stride = int(0.1 * self.soc.get_avg_max_length(0)/max(reads_per_count))
                # bigger stride is more efficient, but the transfer size must never exceed AVG_MAX_LENGTH, so the stride should be set with some safety margin

                # make sure count variable is reset to 0 before starting processor
                self.soc.set_tproc_counter(addr=counter_addr, val=0)
                stats = []

                t_start = time.time()

                # if the tproc is configured for internal start, this will start the program
                # for external start, the program will not start until a start pulse is received
                self.soc.start_tproc()

                # Keep streaming data until you get all of it
                while last_shots < total_shots:
                    if self.stop_flag.is_set():
                        print("streamer loop: got stop flag")
                        break
                    shots = self.soc.get_tproc_counter(addr=counter_addr)
                    # wait until either you've gotten a full stride of measurements or you've finished (so you don't go crazy trying to download every measurement)
                    if shots >= min(last_shots+stride, total_shots):
                        newshots = shots-last_shots
                        # buffer for each channel
                        d_buf = [None for nreads in reads_per_count]

                        # for each adc channel get the single shot data and add it to the buffer
                        for iCh, ch in enumerate(ch_list):
                            newpoints = newshots*reads_per_count[iCh]
                            if newpoints >= self.soc.get_avg_max_length(ch):
                                raise RuntimeError("Overflowed the averages buffer (%d unread samples >= buffer size %d)."
                                                   % (newpoints, self.soc.get_avg_max_length(ch)) +
                                                   "\nYou need to slow down the tProc by increasing relax_delay." +
                                                   "\nIf the TQDM progress bar is enabled, disabling it may help.")

                            addr = last_shots * reads_per_count[iCh] % self.soc.get_avg_max_length(ch)
                            data = self.soc.get_accumulated(ch=ch, address=addr, length=newpoints)
                            d_buf[iCh] = data

                        last_shots += newshots

                        stats = (time.time()-t_start, shots, addr, newshots)
                        self.data_queue.put((newshots, (d_buf, stats)))
                #if last_count==total_count: print("streamer loop: normal completion")

            except Exception as e:
                print("streamer loop: got exception")
                # traceback.print_exc()
                # pass the exception to the main thread
                self.error_queue.put(e)
                # put dummy data in the data queue, to trigger a poll_data read
                self.data_queue.put((0, (None, None)))
            finally:
                # we should set the done flag regardless of whether we completed readout, used the stop flag, or errored out
                self.done_flag.set()
                # set tproc for internal start so we don't run the program repeatedly (this also clears the internal-start register)
                self.soc.start_src("internal")
