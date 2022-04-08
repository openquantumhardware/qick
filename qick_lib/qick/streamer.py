from threading import Thread, Event
from queue import Queue
import queue
import time
import numpy as np

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
        self.stop_flag = Event()
        # The worker thread uses this to tell the main thread when it's done.
        self.done_flag = Event()
        self.done_flag.set()

        # Process object for the streaming readout.
        # daemon=True means the readout thread will be killed if the parent is killed
        self.readout_worker = self.WORKERTYPE(target=self._run_readout, daemon=True)
        self.readout_worker.start()

    def start_readout(self, total_count, counter_addr=1, ch_list=None, reads_per_count=1):
        """
        Start a streaming readout of the average buffers.

        :param total_count: Number of data points expected
        :type total_count: int
        :param counter_addr: Data memory address for the loop counter
        :type counter_addr: int
        :param ch_list: List of readout channels
        :type ch_list: list
        :param reads_per_count: Number of data points to expect per counter increment
        :type reads_per_count: int
        """
        if ch_list is None: ch_list = [0, 1]

        self.total_count = total_count
        self.count = 0

        if not self.readout_worker.is_alive():
            print("restarting readout worker")
            self.start_worker()

        # if there's still a readout job running, stop it
        if self.readout_running():
            print("cleaning up previous readout: stopping streamer loop")
            # tell the readout to stop (this will break the readout loop)
            self.stop_readout()
            self.done_flag.wait()
        if self.data_available():
            # flush all the data in the streamer buffer
            print("clearing streamer buffer")
            self.poll_data(timeout=0.1)
        self.done_flag.clear()
        self.job_queue.put((total_count, counter_addr, ch_list, reads_per_count))


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

    def poll_data(self, totaltime=0.1, timeout=None):
        """
        Get as much data as possible from the data queue.
        Stop when any of the following conditions are met:
        * all the data has been transferred (based on the total_count)
        * we got data, and it has been totaltime seconds since poll_data was called
        * timeout is defined, and the timeout expired without getting new data in the queue
        If there are errors in the error queue, raise the first one.

        :param totaltime: How long to acquire data
        :type totaltime: float
        :param timeout: How long to wait for the next data packet (None = wait forever)
        :type timeout: float
        :return: list of (data, stats) pairs, oldest first
        :rtype: list
        """
        try:
            raise RuntimeError(
                "exception in readout loop") from self.error_queue.get(block=False)
        except queue.Empty:
            pass

        time_end = time.time() + totaltime
        new_data = []
        while self.count < self.total_count and time.time() < time_end:
            try:
                length, data = self.data_queue.get(block=True, timeout=timeout)
                self.count += length
                new_data.append(data)
            except queue.Empty:
                break
        return new_data

    def _run_readout(self):
        """
        Worker thread for the streaming readout

        :param total_count: Number of data points expected
        :type addr: int
        :param counter_addr: Data memory address for the loop counter
        :type counter_addr: int
        :param ch_list: List of readout channels
        :type addr: list
        :param reads_per_count: Number of data points to expect per counter increment
        :type reads_per_count: int
        """
        try:
            while True:
                # wait for a job
                total_count, counter_addr, ch_list, reads_per_count = self.job_queue.get(block=True)

                count = 0
                last_count = 0
                # how many measurements to transfer at a time
                stride = int(0.1 * self.soc.get_avg_max_length(0))
                # bigger stride is more efficient, but the transfer size must never exceed AVG_MAX_LENGTH, so the stride should be set with some safety margin

                # make sure count variable is reset to 0 before starting processor
                self.soc.tproc.single_write(addr=counter_addr, data=0)
                stats = []

                t_start = time.time()

                # if the tproc is configured for internal start, this will start the program
                # for external start, the program will not start until a start pulse is received
                self.soc.tproc.start()

                # Keep streaming data until you get all of it
                while (not self.stop_flag.is_set()) and last_count < total_count:
                    count = self.soc.tproc.single_read(
                        addr=counter_addr)*reads_per_count
                    # wait until either you've gotten a full stride of measurements or you've finished (so you don't go crazy trying to download every measurement)
                    if count >= min(last_count+stride, total_count):
                        addr = last_count % self.soc.get_avg_max_length(0)
                        length = count-last_count
                        if length >= self.soc.get_avg_max_length(0):
                            raise RuntimeError("Overflowed the averages buffer (%d unread samples >= buffer size %d)."
                                               % (length, self.soc.get_avg_max_length(0)) +
                                               "\nYou need to slow down the tProc by increasing relax_delay." +
                                               "\nIf the TQDM progress bar is enabled, disabling it may help.")
                        # transfers must be of even length; trim the length (instead of padding it)
                        # don't trim if this is the last read of the run
                        if count < last_count:
                            length -= length % 2

                        # buffer for each channel
                        d_buf = np.zeros((len(ch_list), 2, length))

                        # for each adc channel get the single shot data and add it to the buffer
                        for iCh, ch in enumerate(ch_list):
                            data = self.soc.get_accumulated(
                                ch=ch, address=addr, length=length)

                            d_buf[iCh] = data

                        last_count += length

                        stats = (time.time()-t_start, count, addr, length)
                        self.data_queue.put((length, (d_buf, stats)))
                self.done_flag.set()

                # Note that the thread will not terminate until the queue is empty.
        except Exception as e:
            self.error_queue.put(e)
