import numpy as np
from qick.qick import SocIp

class AbsPfbAnalysis(SocIp):
    # Trace parameters.
    STREAM_IN_PORT  = 's_axis'
    STREAM_OUT_PORT = 'm_axis'

    # Flags.
    HAS_ADC         = False
    HAS_DMA         = False
    HAS_XFFT        = False
    HAS_ACCUMULATOR = False
    HAS_BUFF_ADC    = False
    HAS_BUFF_PFB    = False
    HAS_BUFF_XFFT   = False

    def configure(self, fs):
        # Channel centers.
        fc = fs/self.dict['N']

        # Channel bandwidth.
        fb = fs/(self.dict['N']/2)

        # Add data into dictionary.
        self.dict['freq'] = {'fs' : fs, 'fc' : fc, 'fb' : fb}
    
    def configure_connections(self, soc):
        self.soc = soc

        ##################################################
        ### Backward tracing: should finish at the ADC ###
        ##################################################
        ((block,port),) = soc.metadata.trace_bus(self.fullpath, self.STREAM_IN_PORT)

        while True:
            blocktype = soc.metadata.mod2type(block)

            if blocktype == "usp_rf_data_converter":
                if not self.HAS_ADC:
                    self.HAS_ADC = True

                    # Get ADC and tile.
                    tile, adc_ch = self.ports2adc(port, None)

                    # Fill adc data dictionary.
                    id_ = str(tile) + str(adc_ch)
                    self.dict['adc'] = {'tile' : tile, 'ch' : adc_ch, 'id' : id_}
                break
            elif blocktype == "axis_broadcaster":
                # Block/port for forward tracing second broadcaster port.
                ((block_tmp, port_tmp),) = soc.metadata.trace_bus(block, 'M01_AXIS')

                # Normal block/port to continue with backwards trace.
                ((block, port),) = soc.metadata.trace_bus(block, 'S_AXIS')

                # Forward tracing: should end at DMA.
                while True:
                    blocktype = soc.metadata.mod2type(block_tmp)

                    if blocktype == "mr_buffer_et":
                        self.HAS_BUFF_ADC = True

                        # Add block into dictionary.
                        self.dict['buff_adc'] = block_tmp

                        # Trace port.
                        ((block_tmp, port_tmp),) = soc.metadata.trace_bus(block_tmp, 'm00_axis')
                    elif blocktype == "axi_dma":
                        # Add dma into dictionary.
                        self.dict['buff_adc_dma'] = block_tmp
                        break

            elif blocktype == "axis_register_slice":
                ((block, port),) = soc.metadata.trace_bus(block, 'S_AXIS')
            elif blocktype == "axis_reorder_iq_v1":
                ((block, port),) = soc.metadata.trace_bus(block, 's_axis')
            elif blocktype == "axis_combiner":
                self.HAS_ADC = True
                # Sanity check: combiner should have 2 slave ports.
                nslave = int(soc.metadata.get_param(block, 'C_NUM_SI_SLOTS'))

                if nslave != 2:
                    raise RuntimeError("Block %s has %d S_AXIS inputs. It should have 2." % (block, nslave))

                # Trace the two interfaces.
                ((block0, port0),) = soc.metadata.trace_bus(block, 'S00_AXIS')
                ((block1, port1),) = soc.metadata.trace_bus(block, 'S01_AXIS')

                # Get ADC and tile.
                tile, adc_ch = self.ports2adc(port0, port1)

                # Fill adc data dictionary.
                id_ = str(tile) + str(adc_ch)
                self.dict['adc'] = {'tile' : tile, 'ch' : adc_ch, 'id' : id_}

                # Keep tracing back.
                block = block0
                port = port0
                break
            else:
                raise RuntimeError("falied to trace port for %s - unrecognized IP block %s" % (self.fullpath, block))

        #################################################
        ### Forward tracing: should finish at the DMA ###
        #################################################
        ((block,port),) = soc.metadata.trace_bus(self.fullpath, self.STREAM_OUT_PORT)

        while True:
            blocktype = soc.metadata.mod2type(block)

            if blocktype == "axi_dma":
                self.HAS_DMA = True

                # Add dma into dictionary.
                self.dict['dma'] = block
                break
            elif blocktype == "axis_broadcaster":
                # Block/port for forward tracing second broadcaster port.
                ((block_tmp, port_tmp),) = soc.metadata.trace_bus(block, 'M01_AXIS')

                # Normal block/port to continue with backwards trace.
                ((block, port),) = soc.metadata.trace_bus(block, 'M00_AXIS')

                # Forward tracing: should end at DMA.
                while True:
                    blocktype = soc.metadata.mod2type(block_tmp)

                    if blocktype == "axis_chsel_pfb_x1":
                        # Temp chsel.
                        chsel_ = block_tmp

                        # Trace port.
                        ((block_tmp, port_tmp),) = soc.metadata.trace_bus(block_tmp, 'm_axis')
                    elif blocktype == "axis_buffer_v1":
                        self.HAS_BUFF_PFB = True

                        # Add block into dictionary.
                        self.dict['buff_pfb_chsel'] = chsel_
                        self.dict['buff_pfb']       = block_tmp

                        # Type for filtering DMA.
                        btype = "pfb"

                        # Trace port.
                        ((block_tmp, port_tmp),) = soc.metadata.trace_bus(block_tmp, 'm_axis')
                    elif blocktype == "axis_buffer_uram_v1":
                        self.HAS_BUFF_XFFT = True

                        # Add block into dictionary.
                        self.dict['buff_xfft_chsel'] = chsel_
                        self.dict['buff_xfft']       = block_tmp

                        # Type for filtering DMA.
                        btype = "xfft"

                        # Trace port.
                        ((block_tmp, port_tmp),) = soc.metadata.trace_bus(block_tmp, 'm_axis')
                    elif blocktype == "axi_dma":
                        # Add dma into dictionary.
                        if btype == "pfb":
                            self.dict['buff_pfb_dma'] = block_tmp
                        elif btype == "xfft":
                            self.dict['buff_xfft_dma'] = block_tmp
                        break
            elif blocktype == "axis_clock_converter":
                # Trace port.
                ((block, port),) = soc.metadata.trace_bus(block, 'M_AXIS')
            elif blocktype == "axis_xfft_16x16384" or blocktype == "axis_xfft_16x32768":
                self.HAS_XFFT = True

                # Add block into dictionary.
                self.dict['xfft'] = block

                ((block, port),) = soc.metadata.trace_bus(block, 'm_axis')
            elif blocktype == "axis_accumulator_v1":
                self.HAS_ACCUMULATOR = True

                # Add block into dictionary.
                self.dict['accumulator'] = block

                ((block, port),) = soc.metadata.trace_bus(block, 'm_axis')

            else:
                raise RuntimeError("falied to trace port for %s - unrecognized IP block %s" % (self.fullpath, block))

    def ports2adc(self, port0, port1):
        # This function cheks the given ports correspond to the same ADC.
        # The correspondance is (IQ mode):
        #
        # ADC0, tile 0.
        # m00_axis: I
        # m01_axis: Q
        #
        # ADC1, tile 0.
        # m02_axis: I
        # m03_axis: Q
        #
        # ADC0, tile 1.
        # m10_axis: I
        # m11_axis: Q
        #
        # ADC1, tile 1.
        # m12_axis: I
        # m13_axis: Q
        #
        # ADC0, tile 2.
        # m20_axis: I
        # m21_axis: Q
        #
        # ADC1, tile 2.
        # m22_axis: I
        # m23_axis: Q
        #
        # ADC0, tile 3.
        # m30_axis: I
        # m31_axis: Q
        #
        # ADC1, tile 3.
        # m32_axis: I
        # m33_axis: Q
        adc_dict = {
            '0' :   {
                        '0' : {'port 0' : 'm00', 'port 1' : 'm01'}, 
                        '1' : {'port 0' : 'm02', 'port 1' : 'm03'}, 
                    },
            '1' :   {
                        '0' : {'port 0' : 'm10', 'port 1' : 'm11'}, 
                        '1' : {'port 0' : 'm12', 'port 1' : 'm13'}, 
                    },
            '2' :   {
                        '0' : {'port 0' : 'm20', 'port 1' : 'm21'}, 
                        '1' : {'port 0' : 'm22', 'port 1' : 'm23'}, 
                    },
            '3' :   {
                        '0' : {'port 0' : 'm30', 'port 1' : 'm31'}, 
                        '1' : {'port 0' : 'm32', 'port 1' : 'm33'}, 
                    },
                    }

        p0_n = port0[0:3]

        # Find adc<->port.
        # IQ on same port.
        if port1 is None:
            tile = p0_n[1]
            adc  = p0_n[2]
            return tile,adc

        # IQ on different ports.
        else:
            p1_n = port1[0:3]

            # IQ on different ports.
            for tile in adc_dict.keys():
                for adc in adc_dict[tile].keys():
                    # First possibility.
                    if p0_n == adc_dict[tile][adc]['port 0']:
                        if p1_n == adc_dict[tile][adc]['port 1']:
                            return tile,adc
                    # Second possibility.
                    if p1_n == adc_dict[tile][adc]['port 0']:
                        if p0_n == adc_dict[tile][adc]['port 1']:
                            return tile,adc

        # If I got here, adc not found.
        raise RuntimeError("Cannot find correspondance with any ADC for ports %s,%s" % (port0,port1))


    def freq2ch(self,f):
        """
        Convert from frequency to PFB channel number
        
        Parameters:
        -----------
            f : float, list of floats, or numpy array of floats
                frequency in MHz
        
        Returns:
        --------
            ch : int or numpyr array of np.int64
                The channel number that contains the frequency
            
        Raises:
            ValueError
                if any of the frequencies are outside the allowable range of +/- fs/2
                
        """
        # if f is a list convert it to numpy array
        if isinstance(f, list):
            f = np.array(f)
            
        # Check if all frequencies are in -fs/2 .. fs/2
        fMax = self.dict['freq']['fs']/2
        if np.any(abs(f) > fMax):
                    raise ValueError("Frequency value %s out of allowed range [%f,%f]" % (str(f),-fMax, fMax))

        k = np.round(f/self.dict['freq']['fc']).astype(int)
        if isinstance(k,np.int64):
            if k < 0:
                k += self.dict['N']
        else:
            k[k<0] += self.dict['N']
        return k
    
    def ch2freq(self,ch):
        """
        Convert from PFB input channel number to frequency at center of bin
        
        Parameters:
        -----------
           ch : int or numpy array of np.int64
                The channel number that contains the frequency
         
        Returns:
        --------
           f : float, list of floats, or numpy array of floats
                frequency in MHz at the center of the bin
             
        Raises:
            ValueError
                if any of the bin numbers are out of range [0,N)
                
        """
        # if ch is a list convert it to numpy array
        if isinstance(ch, list):
            ch = np.array(ch)
        N = self.dict['N']
        if np.any(ch < 0) or np.any(ch >= N):
                    raise ValueError("Channel value %s out of allowed range [0,%d)" % (str(ch),N))
      
        fc = self.dict['freq']['fc']
        freq = ch*fc
        
        if isinstance(ch, int) or isinstance(ch, np.int64):
            if ch >= N//2: 
                freq -= N*fc
        else:           
            freq = ch*fc
            freq[ch >= N//2] -= N*fc
        return freq
            
    def qout(self, qout):
        self.qout_reg = qout

class AxisPfbAnalysis(AbsPfbAnalysis):
    """
    AxisPfbAnalysis class
    Supports AxisPfb4x1024V1, AxisPfbaPr4x256V1, AxisPfb4x64V1, AxisPfb8x16V1
    """
    bindto = ['user.org:user:axis_pfb_4x1024_v1:1.0'   ,
              'user.org:user:axis_pfb_4x64_v1:1.0'     ,
              'user.org:user:axis_pfba_pr_4x256_v1:1.0',
              'user.org:user:axis_pfb_8x16_v1:1.0'     ]
    
    def __init__(self, description):
        # Initialize ip
        super().__init__(description)

        self.REGISTERS = {'qout_reg' : 0}
        
        # Default registers.
        self.qout_reg = 0

        # Dictionary.
        self.dict = {}
        self.dict['N'] = int(description['parameters']['N'])

