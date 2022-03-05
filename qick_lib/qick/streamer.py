import numpy as np
from multiprocessing import Process, Queue, Event
import queue
import time
import os


class DataStreamer():
    """
    Uses a separate process to read data from the average buffers.

    We don't lock the QickSoc or the IPs. The user is responsible for not disrupting a readout in progress.

    :param soc: The QickSoc object.
    :type soc: QickSoc
    """

    def __init__(self, soc):
        self.soc = soc

        # Process object for the streaming readout.
        self.readout_process = None

    def start_readout(self, total_count, counter_addr=1, ch_list=[0, 1], reads_per_count=1):
        """
        Start a streaming readout of the average buffers.

        :param total_count: Number of data points expected
        :type addr: int
        :param counter_addr: Data memory address for the loop counter
        :type counter_addr: int
        :param ch_list: List of readout channels
        :type addr: list
        :param reads_per_count: Number of data points to expect per counter increment
        :type reads_per_count: int
        """

        # if there's still a readout process running, stop it
        if self.readout_alive():
            print("cleaning up previous readout: stopping streamer loop")
            # tell the readout to stop (this will break the readout loop)
            self.stop_readout()
            # get all the data in the streamer buffer (this will allow the readout process to terminate)
            while self.readout_alive():
                print("clearing streamer buffer")
                time.sleep(0.5)
                self.poll_data()

        # Initialize flags and queues.
        # Passes data from the worker process to the main process.
        self.data_queue = Queue()
        # Passes exceptions from the worker process to the main process.
        self.error_queue = Queue()
        # The main process can use this flag to tell the worker process to stop.
        self.stop_flag = Event()
        # The worker process uses this to tell the main process when it's done.
        self.done_flag = Event()

        # daemon=True means the readout process will be killed if the parent is killed
        self.readout_process = Process(target=self._run_readout, args=(
            total_count, counter_addr, ch_list, reads_per_count), daemon=True)
        self.readout_process.start()

    def stop_readout(self):
        """
        Signal the readout loop to break.
        The readout process will stay alive until you have read any data already in the data queue.
        """
        self.stop_flag.set()

    def readout_done(self):
        """
        Test if the readout loop is running.
        There may still be unread data in the queue.

        :return: readout loop flag
        :rtype: bool
        """
        return self.done_flag.is_set()

    def readout_alive(self):
        """
        Test if the readout process is still alive.
        This is true as long as the readout loop is running, or there are unread items in the queues.
        You will not be able to start a new readout until this is false.

        :return: readout process status
        :rtype: bool
        """
        return self.readout_process is not None and self.readout_process.is_alive()

    def poll_data(self):
        """
        Get as much data as possible from the data queue.
        If there are errors in the error queue, raise the first one.

        :return: list of (data, stats) pairs, oldest first
        :rtype: list
        """
        try:
            raise RuntimeError(
                "exception in readout loop") from self.error_queue.get(block=False)
        except queue.Empty:
            pass

        new_data = []
        while True:
            try:
                new_data.append(self.data_queue.get(timeout=0.001))
            except queue.Empty:
                break
        return new_data

    def _run_readout(self, total_count, counter_addr, ch_list, reads_per_count):
        """
        Worker process for the streaming readout

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
            count = 0
            last_count = 0
            # how many measurements to transfer at a time
            stride = int(0.1 * self.soc.get_avg_max_length(0))
            # bigger stride is more efficient, but the transfer size must never exceed AVG_MAX_LENGTH, so the stride should be set with some safety margin

            self.soc.tproc.stop()

            # make sure count variable is reset to 0 before starting processor
            self.soc.tproc.single_write(addr=counter_addr, data=0)
            stats = []

            t_start = time.time()

            self.soc.tproc.start()
            # Keep streaming data until you get all of it
            while (not self.stop_flag.is_set()) and last_count < total_count:
                count = self.soc.tproc.single_read(
                    addr=counter_addr)*reads_per_count
                # wait until either you've gotten a full stride of measurements or you've finished (so you don't go crazy trying to download every measurement)
                if count >= min(last_count+stride, total_count):
                    addr = last_count % self.soc.get_avg_max_length(0)
                    length = count-last_count
                    # transfers must be of even length; trim the length (instead of padding it)
                    length -= length % 2
                    if length >= self.soc.get_avg_max_length(0):
                        raise RuntimeError("Overflowed the averages buffer (%d unread samples >= buffer size %d)."
                                           % (length, self.soc.get_avg_max_length(0)) +
                                           "\nYou need to slow down the tProc by increasing relax_delay." +
                                           "\nIf the TQDM progress bar is enabled, disabling it may help.")

                    # buffer for each channel
                    d_buf = np.zeros((len(ch_list), 2, length))

                    # for each adc channel get the single shot data and add it to the buffer
                    for iCh, ch in enumerate(ch_list):
                        data = self.soc.get_accumulated(
                            ch=ch, address=addr, length=length)

                        d_buf[iCh] = data

                    last_count += length

                    stats = (time.time()-t_start, count, addr, length)
                    self.data_queue.put((d_buf, stats))
            self.done_flag.set()

            # Note that the process will not terminate until the queue is empty.
        except Exception as e:
            self.error_queue.put(e)
