# RF board hardware README

Last updated on 9/25/2022.

Please download the [linked zip file](https://drive.google.com/file/d/18OvfUnnmzwmpfNI-T6RhhX2rVHdvlVzb/view?usp=sharing) to see the gerbers, BOM and spec file for the ZCU111 RF board V4. 
As of 9/25/2022, there are some modifications that the assembler will need to make: 
 
* C518 should not be installed.
* R84 value should be changed from 18.2K to 9.76K
* There are oscillations on some RF ADC inputs.
* Added 0.4"x0.65" strip of 3M AB5010S EMI Absorber under the first RF covers of the RF ADC channels.
* Note that AB5010S is obsolete and replaced with AB5010SHF (Halogen Free).
 
