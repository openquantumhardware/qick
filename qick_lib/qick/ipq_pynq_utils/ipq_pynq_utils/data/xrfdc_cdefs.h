typedef struct {
        u32 RefTile;
        u32 IsPLL;
        int Target[4];
        int Scan_Mode;
        int DTC_Code[4];
        int Num_Windows[4];
        int Max_Gap[4];
        int Min_Gap[4];
        int Max_Overlap[4];
} XRFdc_MTS_DTC_Settings;

/**
 * MTS Sync Settings.
 */
typedef struct {
        u32 RefTile;
        u32 Tiles;
        int Target_Latency;
        int Offset[4];
        int Latency[4];
        int Marker_Delay;
        int SysRef_Enable;
        XRFdc_MTS_DTC_Settings DTC_Set_PLL;
        XRFdc_MTS_DTC_Settings DTC_Set_T1;
} XRFdc_MultiConverter_Sync_Config;

u32 XRFdc_MultiConverter_Sync(XRFdc *InstancePtr, u32 Type, XRFdc_MultiConverter_Sync_Config *ConfigPtr);
u32 XRFdc_MultiConverter_Init(XRFdc_MultiConverter_Sync_Config *ConfigPtr, int *PLL_CodesPtr, int *T1_CodesPtr, u32 RefTile);
u32 XRFdc_MTS_Sysref_Config(XRFdc *InstancePtr, XRFdc_MultiConverter_Sync_Config *DACSyncConfigPtr, XRFdc_MultiConverter_Sync_Config *ADCSyncConfigPtr, u32 SysRefEnable);
u32 XRFdc_GetMTSEnable(XRFdc *InstancePtr, u32 Type, u32 Tile, u32 *EnablePtr);
