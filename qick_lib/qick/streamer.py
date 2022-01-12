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
        self.readout_process=None

        # Passes data from the worker process to the main process.
        self.data_queue = Queue()
        # The main process can use this flag to tell the worker process to stop.
        self.stop_flag = Event()
        # The worker process uses this to tell the main process when it's done.
        self.done_flag = Event()

    def start_readout(self,total_count, counter_addr=1, ch_list=[0,1]):
        """
        Start a streaming readout of the average buffers.

        :param total_count: Number of data points expected
        :type addr: int
        :param counter_addr: Data memory address for the loop counter
        :type counter_addr: int
        :param ch_list: List of readout channels
        :type addr: list
        """

        if self.readout_alive():
            raise RuntimeError("Cannot start a readout when the readout is still alive.")

        # Initialize flags.
        self.stop_flag.clear()
        self.done_flag.clear()

        # daemon=True means the readout process will be killed if the parent is killed
        self.readout_process = Process(target=self._run_readout, args=(total_count, counter_addr, ch_list), daemon=True)
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
        This is true as long as the readout loop is running, or there is unread data in the queue.
        You will not be able to start a new readout until this is false.

        :return: readout process status
        :rtype: bool
        """
        return self.readout_process is not None and self.readout_process.is_alive()

    def poll_data(self):
        """
        Get as much data as possible from the data queue.

        :return: list of (data, stats) pairs, oldest first
        :rtype: list
        """
        new_data = []
        while True:
            try:
                new_data.append(self.data_queue.get(timeout=0.001))
            except queue.Empty:
                break
        return new_data

    def _run_readout(self, total_count, counter_addr, ch_list):
        """
        Worker process for the streaming readout

        :param total_count: Number of data points expected
        :type addr: int
        :param counter_addr: Data memory address for the loop counter
        :type counter_addr: int
        :param ch_list: List of readout channels
        :type addr: list
        """
        count=0
        last_count=0
        stride=int(0.5 * self.soc.get_avg_max_length(0)) # how many measurements to transfer at a time
        # bigger stride is more efficient, but the transfer size must never exceed AVG_MAX_LENGTH, so the stride should be set with some safety margin

        self.soc.stop()

        self.soc.single_write(addr= counter_addr,data=0)   #make sure count variable is reset to 0 before starting processor
        stats=[]

        t_start = time.time()

        self.soc.start()
        while (not self.stop_flag.is_set()) and count<total_count:   # Keep streaming data until you get all of it
            count = self.soc.single_read(addr= counter_addr)
            if count>=min(last_count+stride,total_count-1):  #wait until either you've gotten a full stride of measurements or you've finished (so you don't go crazy trying to download every measurement)
                addr=last_count % self.soc.get_avg_max_length(0)
                length = count-last_count
                length -= length%2 # transfers must be of even length; trim the length (instead of padding it)
                if length>=self.soc.get_avg_max_length(0):
                    raise RuntimeError("Overflowed the averages buffer (%d unread samples >= buffer size %d)."
                            %(length, self.soc.get_avg_max_length(0)) +
                            "\nYou need to slow down the tProc by increasing relax_delay." +
                            "\nIf the TQDM progress bar is enabled, disabling it may help.")

                # buffer for each channel
                d_buf=np.zeros((len(ch_list),2,length))

                for iCh, ch in enumerate(ch_list):  #for each adc channel get the single shot data and add it to the buffer
                    data = self.soc.get_accumulated(ch=ch,address=addr, length=length)

                    d_buf[iCh]=data

                last_count+=length

                stats = (time.time()-t_start, count,addr, length)
                self.data_queue.put((d_buf, stats))
        self.done_flag.set()

        # Note that the process will not terminate until the queue is empty.

