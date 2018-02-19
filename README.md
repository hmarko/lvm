[root@RHEL1 lvmmgmt]# ./manage_pvmove.pl
WARNING: /dev/mapper/vg1_pv_log1 source PV:vg1_new_pv_log1 is not part of a VG
WARNING: /dev/mapper/vg1_pv_data5 source PV:vg1_new_pv_data5 is not part of a VG
starting pvmove from /dev/mapper/vg1_new_pv_data3 to /dev/mapper/vg1_pv_data3
reducing PV:/dev/mapper/vg1_new_pv_data3 from VG:vg1_pv_data :  Removed "/dev/mapper/vg1_new_pv_data3" from volume group "vg1_pv_data"

starting pvmove from /dev/mapper/vg1_new_pv_log2 to /dev/mapper/vg1_pv_log2
reducing PV:/dev/mapper/vg1_new_pv_log2 from VG:vg1_pv_log :  Removed "/dev/mapper/vg1_new_pv_log2" from volume group "vg1_pv_log"

starting pvmove from /dev/mapper/vg1_new_pv_log3 to /dev/mapper/vg1_pv_log3
reducing PV:/dev/mapper/vg1_new_pv_log3 from VG:vg1_pv_log :  Removed "/dev/mapper/vg1_new_pv_log3" from volume group "vg1_pv_log"

starting pvmove from /dev/mapper/vg1_new_pv_arch3 to /dev/mapper/vg1_pv_arch3
reducing PV:/dev/mapper/vg1_new_pv_arch3 from VG:vg1_pv_arch :  Removed "/dev/mapper/vg1_new_pv_arch3" from volume group "vg1_pv_arch"

starting pvmove from /dev/mapper/vg1_new_pv_arch2 to /dev/mapper/vg1_pv_arch2
reducing PV:/dev/mapper/vg1_new_pv_arch2 from VG:vg1_pv_arch :  Removed "/dev/mapper/vg1_new_pv_arch2" from volume group "vg1_pv_arch"

starting pvmove from /dev/mapper/vg1_new_pv_arch1 to /dev/mapper/vg1_pv_arch1
reducing PV:/dev/mapper/vg1_new_pv_arch1 from VG:vg1_pv_arch :  Removed "/dev/mapper/vg1_new_pv_arch1" from volume group "vg1_pv_arch"

starting pvmove from /dev/mapper/vg1_new_pv_arch4 to /dev/mapper/vg1_pv_arch4
reducing PV:/dev/mapper/vg1_new_pv_arch4 from VG:vg1_pv_arch :  Removed "/dev/mapper/vg1_new_pv_arch4" from volume group "vg1_pv_arch"

starting pvmove from /dev/mapper/vg1_new_pv_data1 to /dev/mapper/vg1_pv_data1
reducing PV:/dev/mapper/vg1_new_pv_data1 from VG:vg1_pv_data :  Removed "/dev/mapper/vg1_new_pv_data1" from volume group "vg1_pv_data"

starting pvmove from /dev/mapper/vg1_new_pv_data4 to /dev/mapper/vg1_pv_data4
^C
[root@RHEL1 lvmmgmt]# ./manage_pvmove.pl
WARNING: /dev/mapper/vg1_pv_data3 source PV:vg1_new_pv_data3 is not part of a VG
WARNING: /dev/mapper/vg1_pv_log2 source PV:vg1_new_pv_log2 is not part of a VG
WARNING: /dev/mapper/vg1_pv_log1 source PV:vg1_new_pv_log1 is not part of a VG
WARNING: /dev/mapper/vg1_pv_log3 source PV:vg1_new_pv_log3 is not part of a VG
WARNING: /dev/mapper/vg1_pv_data5 source PV:vg1_new_pv_data5 is not part of a VG
WARNING: /dev/mapper/vg1_pv_arch3 source PV:vg1_new_pv_arch3 is not part of a VG
WARNING: /dev/mapper/vg1_pv_arch2 source PV:vg1_new_pv_arch2 is not part of a VG
WARNING: /dev/mapper/vg1_pv_arch1 source PV:vg1_new_pv_arch1 is not part of a VG
WARNING: /dev/mapper/vg1_pv_arch4 source PV:vg1_new_pv_arch4 is not part of a VG
WARNING: /dev/mapper/vg1_pv_data1 source PV:vg1_new_pv_data1 is not part of a VG
WARNING: /dev/mapper/vg1_pv_data4 source PV:/dev/mapper/vg1_new_pv_data4 does not contain any data
reducing PV:/dev/mapper/vg1_new_pv_data4 from VG:vg1_pv_data :  Removed "/dev/mapper/vg1_new_pv_data4" from volume group "vg1_pv_data"

starting pvmove from /dev/mapper/vg1_new_pv_data2 to /dev/mapper/vg1_pv_data2
^C
[root@RHEL1 lvmmgmt]# ./manage_pvmove.pl
WARNING: /dev/mapper/vg1_pv_data3 source PV:vg1_new_pv_data3 is not part of a VG
WARNING: /dev/mapper/vg1_pv_log2 source PV:vg1_new_pv_log2 is not part of a VG
WARNING: /dev/mapper/vg1_pv_log1 source PV:vg1_new_pv_log1 is not part of a VG
WARNING: /dev/mapper/vg1_pv_log3 source PV:vg1_new_pv_log3 is not part of a VG
WARNING: /dev/mapper/vg1_pv_data5 source PV:vg1_new_pv_data5 is not part of a VG
WARNING: /dev/mapper/vg1_pv_arch3 source PV:vg1_new_pv_arch3 is not part of a VG
WARNING: /dev/mapper/vg1_pv_arch2 source PV:vg1_new_pv_arch2 is not part of a VG
WARNING: /dev/mapper/vg1_pv_arch1 source PV:vg1_new_pv_arch1 is not part of a VG
WARNING: /dev/mapper/vg1_pv_arch4 source PV:vg1_new_pv_arch4 is not part of a VG
WARNING: /dev/mapper/vg1_pv_data1 source PV:vg1_new_pv_data1 is not part of a VG
WARNING: /dev/mapper/vg1_pv_data4 source PV:vg1_new_pv_data4 is not part of a VG
WARNING: /dev/mapper/vg1_pv_data2 free size is m while used size on source PV is m
 {"vg1_pv_arch1":{"nomigrate":1},"vg1_pv_arch4":{"nomigrate":1},"vg1_pv_data3":{"nomigrate":1},"vg1_pv_data1":{"nomigrate":1},"vg1_pv_log2":{"nomigrate":1},"vg1_pv_data4":{"nomigrate":1},"vg1_pv_log1":{"nomigrate":1},"vg1_pv_log3":{"nomigrate":1},"vg1_pv_data5":{"nomigrate":1},"vg1_pv_arch3":{"nomigrate":1},"vg1_pv_arch2":{"nomigrate":1},"vg1_pv_data2":{"nomigrate":1}}
[root@RHEL1 lvmmgmt]# vgs
  VG          #PV #LV #SN Attr   VSize VFree
  vg1_pv_arch   4   1   0 wz--n- 3.98g 1008.00m
  vg1_pv_data   6   1   0 wz--n- 6.08g    1.70g
  vg1_pv_log    3   1   0 wz--n- 2.99g 1012.00m
[root@RHEL1 lvmmgmt]# pvs
  PV                           VG          Fmt  Attr PSize    PFree
  /dev/mapper/vg1_new_pv_arch1             lvm2 ----    1.10g    1.10g
  /dev/mapper/vg1_new_pv_arch2             lvm2 ----    1.10g    1.10g
  /dev/mapper/vg1_new_pv_arch3             lvm2 ----    1.10g    1.10g
  /dev/mapper/vg1_new_pv_arch4             lvm2 ----    1.10g    1.10g
  /dev/mapper/vg1_new_pv_data1             lvm2 ----    1.10g    1.10g
  /dev/mapper/vg1_new_pv_data2 vg1_pv_data lvm2 a--u    1.10g  228.00m
  /dev/mapper/vg1_new_pv_data3             lvm2 ----    1.10g    1.10g
  /dev/mapper/vg1_new_pv_data4             lvm2 ----    1.10g    1.10g
  /dev/mapper/vg1_new_pv_data5             lvm2 ----    1.10g    1.10g
  /dev/mapper/vg1_new_pv_log1              lvm2 ----    1.10g    1.10g
  /dev/mapper/vg1_new_pv_log2              lvm2 ----    1.10g    1.10g
  /dev/mapper/vg1_new_pv_log3              lvm2 ----    1.10g    1.10g
  /dev/mapper/vg1_pv_arch1     vg1_pv_arch lvm2 a--u 1020.00m  252.00m
  /dev/mapper/vg1_pv_arch2     vg1_pv_arch lvm2 a--u 1020.00m  252.00m
  /dev/mapper/vg1_pv_arch3     vg1_pv_arch lvm2 a--u 1020.00m  252.00m
  /dev/mapper/vg1_pv_arch4     vg1_pv_arch lvm2 a--u 1020.00m  252.00m
  /dev/mapper/vg1_pv_data1     vg1_pv_data lvm2 a--u 1020.00m  124.00m
  /dev/mapper/vg1_pv_data2     vg1_pv_data lvm2 a--u 1020.00m  124.00m
  /dev/mapper/vg1_pv_data3     vg1_pv_data lvm2 a--u 1020.00m  124.00m
  /dev/mapper/vg1_pv_data4     vg1_pv_data lvm2 a--u 1020.00m  124.00m
  /dev/mapper/vg1_pv_data5     vg1_pv_data lvm2 a--u 1020.00m 1020.00m
  /dev/mapper/vg1_pv_log1      vg1_pv_log  lvm2 a--u 1020.00m       0
  /dev/mapper/vg1_pv_log2      vg1_pv_log  lvm2 a--u 1020.00m       0
  /dev/mapper/vg1_pv_log3      vg1_pv_log  lvm2 a--u 1020.00m 1012.00m
[root@RHEL1 lvmmgmt]# ./manage_pvmove.pl
WARNING: /dev/mapper/vg1_pv_data3 source PV:vg1_new_pv_data3 is not part of a VG
WARNING: /dev/mapper/vg1_pv_log2 source PV:vg1_new_pv_log2 is not part of a VG
WARNING: /dev/mapper/vg1_pv_log1 source PV:vg1_new_pv_log1 is not part of a VG
WARNING: /dev/mapper/vg1_pv_log3 source PV:vg1_new_pv_log3 is not part of a VG
WARNING: /dev/mapper/vg1_pv_data5 source PV:vg1_new_pv_data5 is not part of a VG
WARNING: /dev/mapper/vg1_pv_arch3 source PV:vg1_new_pv_arch3 is not part of a VG
WARNING: /dev/mapper/vg1_pv_arch2 source PV:vg1_new_pv_arch2 is not part of a VG
WARNING: /dev/mapper/vg1_pv_arch1 source PV:vg1_new_pv_arch1 is not part of a VG
WARNING: /dev/mapper/vg1_pv_arch4 source PV:vg1_new_pv_arch4 is not part of a VG
WARNING: /dev/mapper/vg1_pv_data1 source PV:vg1_new_pv_data1 is not part of a VG
WARNING: /dev/mapper/vg1_pv_data4 source PV:vg1_new_pv_data4 is not part of a VG
WARNING: /dev/mapper/vg1_pv_data2 free size is m while used size on source PV is m
 {"vg1_pv_arch1":{"nomigrate":1},"vg1_pv_arch4":{"nomigrate":1},"vg1_pv_data3":{"nomigrate":1},"vg1_pv_data1":{"nomigrate":1},"vg1_pv_log2":{"nomigrate":1},"vg1_pv_data4":{"nomigrate":1},"vg1_pv_log1":{"nomigrate":1},"vg1_pv_log3":{"nomigrate":1},"vg1_pv_data5":{"nomigrate":1},"vg1_pv_arch3":{"nomigrate":1},"vg1_pv_arch2":{"nomigrate":1},"vg1_pv_data2":{"nomigrate":1}}
[root@RHEL1 lvmmgmt]# vgmove
-bash: vgmove: command not found
[root@RHEL1 lvmmgmt]# pvmove
  /dev/mapper/vg1_new_pv_data2: Moved: 100.0%
[root@RHEL1 lvmmgmt]# vgmove
-bash: vgmove: command not found
[root@RHEL1 lvmmgmt]# ./manage_pvmove.pl
WARNING: /dev/mapper/vg1_pv_data3 source PV:vg1_new_pv_data3 is not part of a VG
WARNING: /dev/mapper/vg1_pv_log2 source PV:vg1_new_pv_log2 is not part of a VG
WARNING: /dev/mapper/vg1_pv_log1 source PV:vg1_new_pv_log1 is not part of a VG
WARNING: /dev/mapper/vg1_pv_log3 source PV:vg1_new_pv_log3 is not part of a VG
WARNING: /dev/mapper/vg1_pv_data5 source PV:vg1_new_pv_data5 is not part of a VG
WARNING: /dev/mapper/vg1_pv_arch3 source PV:vg1_new_pv_arch3 is not part of a VG
WARNING: /dev/mapper/vg1_pv_arch2 source PV:vg1_new_pv_arch2 is not part of a VG
WARNING: /dev/mapper/vg1_pv_arch1 source PV:vg1_new_pv_arch1 is not part of a VG
WARNING: /dev/mapper/vg1_pv_arch4 source PV:vg1_new_pv_arch4 is not part of a VG
WARNING: /dev/mapper/vg1_pv_data1 source PV:vg1_new_pv_data1 is not part of a VG
WARNING: /dev/mapper/vg1_pv_data4 source PV:vg1_new_pv_data4 is not part of a VG
WARNING: /dev/mapper/vg1_pv_data2 source PV:/dev/mapper/vg1_new_pv_data2 does not contain any data
reducing PV:/dev/mapper/vg1_new_pv_data2 from VG:vg1_pv_data :  Removed "/dev/mapper/vg1_new_pv_data2" from volume group "vg1_pv_data"

 {"vg1_pv_arch1":{"nomigrate":1},"vg1_pv_arch4":{"nomigrate":1},"vg1_pv_data3":{"nomigrate":1},"vg1_pv_data1":{"nomigrate":1},"vg1_pv_log2":{"nomigrate":1},"vg1_pv_data4":{"nomigrate":1},"vg1_pv_log1":{"nomigrate":1},"vg1_new_pv_data2":{"pvreducedone":1},"vg1_pv_log3":{"nomigrate":1},"vg1_pv_data5":{"nomigrate":1},"vg1_pv_arch3":{"nomigrate":1},"vg1_pv_arch2":{"nomigrate":1},"vg1_pv_data2":{"nomigrate":1}}

