import pandas as pd
import matplotlib.pyplot as plt

hbw_sensors = ["i1_light_barrier_interrupted", "i4_light_barrier_interrupted", "m3_speed", "m1_speed", "current_state", "timestamp"]
qc_sensors = ["i6_light_barrier_interrupted", "timestamp"]
vgr_sensors = ["o7_compressor_power_level", "o8_valve_open", "current_state", "timestamp"]
oven_sensors = ["i5_light_barrier_interrupted", "current_state", "timestamp"]

df_oven = pd.read_csv(f'/home/janik/Data/iotp_position/Factory_Log/oven.csv', usecols=oven_sensors)
df_qc = pd.read_csv("/home/janik/Data/iotp_position/Factory_Log/sortingMachine.csv", usecols=qc_sensors)
df_hbw = pd.read_csv("/home/janik/Data/iotp_position/Factory_Log/highBay.csv", usecols=hbw_sensors)
df_vgr = pd.read_csv(f'/home/janik/Data/iotp_position/Factory_Log/vacuum_gripper.csv', usecols=vgr_sensors)

df_oven = df_oven.rename(columns={i: "oven_" + i for i in df_oven.columns if i != "timestamp"})
df_qc = df_qc.rename(columns={i: "qc_" + i for i in df_qc.columns if i != "timestamp"})
df_vgr = df_vgr.rename(columns={i: "vgr_" + i for i in df_vgr.columns if i != "timestamp"})
df_hbw = df_hbw.rename(columns={i: "hbw_" + i for i in df_hbw.columns if i != "timestamp"})

result = pd.concat([df_oven, df_qc, df_vgr, df_hbw])
result["timestamp"] = pd.to_datetime(result["timestamp"], format='%Y-%m-%d %H:%M:%S.%f')
result.sort_values(by="timestamp", inplace=True)
result_filled = result.fillna(method="bfill")

for col in result_filled.columns:
    if "light" in col or "valve" in col:
        result_filled[col] = (result_filled[col].astype(str) == "True").astype(int)
    elif "speed" in col:
        result_filled[col] = (result_filled[col] != 0).astype(int)
    elif "current_state" in col:
        result_filled[col] = (result_filled[col] == "not ready").astype(int)
    elif "power" in col:
        result_filled[col] = (result_filled[col] != 0).astype(int)
#result_filled.plot.line(x="timestamp", figsize=(60, 10))
#plt.show()

result_filled.plot.line(x="timestamp", y=["hbw_i1_light_barrier_interrupted",
                                          "vgr_o7_compressor_power_level",
                                          "oven_i5_light_barrier_interrupted",
                                          "qc_i6_light_barrier_interrupted",
                                          "vgr_current_state"], figsize=(60, 10))
plt.show()

hbw_sensors = ["hbw_" + i for i in hbw_sensors if i != "timestamp"]
qc_sensors = ["qc_" + i for i in qc_sensors if i != "timestamp"]
oven_sensors = ["oven_" + i for i in oven_sensors if i != "timestamp"]
vgr_sensors = ["vgr_" + i for i in vgr_sensors if i != "timestamp"]

for fst in [hbw_sensors, qc_sensors, oven_sensors, vgr_sensors]:
    for snd in [hbw_sensors, qc_sensors, oven_sensors, vgr_sensors]:
        for i in fst:
            for j in snd:
                if i != j:
                    result_filled.plot.line(x="timestamp", y=[i, j], figsize=(30, 10))
                    plt.savefig(f"/home/janik/Data/iotp_position/Factory_Log/{i}+{j}.png")



