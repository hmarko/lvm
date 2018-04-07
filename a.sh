ssh vsadmin@svm_linux vol create -volume XIV1 -space-guarantee none -aggregate aggr3 -size 100g -state online -percent-snapshot-space 0
ssh vsadmin@svm_linux vol efficiency on -volume XIV1
ssh vsadmin@svm_linux vol efficiency modify -volume XIV1 -inline-compression true -compression true -policy default
ssh vsadmin@svm_linux lun create -path /vol/XIV1/vg3-1 -ostype linux -size 100g -space-reserve disabled
ssh vsadmin@svm_linux lun create -path /vol/XIV1/vg3-2 -ostype linux -size 100g -space-reserve disabled
ssh vsadmin@svm_linux lun create -path /vol/XIV1/vg3-3 -ostype linux -size 100g -space-reserve disabled
ssh vsadmin@svm_linux lun create -path /vol/XIV1/vg4-1 -ostype linux -size 80g -space-reserve disabled
ssh vsadmin@svm_linux lun create -path /vol/XIV1/vg4-2 -ostype linux -size 80g -space-reserve disabled

ssh vsadmin@svm_linux lun map -path /vol/XIV1/vg3-1 -igroup RHEL1
ssh vsadmin@svm_linux lun map -path /vol/XIV1/vg3-2 -igroup RHEL1
ssh vsadmin@svm_linux lun map -path /vol/XIV1/vg3-3 -igroup RHEL1
ssh vsadmin@svm_linux lun map -path /vol/XIV1/vg4-1 -igroup RHEL1
ssh vsadmin@svm_linux lun map -path /vol/XIV1/vg4-2 -igroup RHEL1


ssh vsadmin@svm_linux vol create -volume XIV2 -space-guarantee none -aggregate aggr3 -size 100g -state online -percent-snapshot-space 0
ssh vsadmin@svm_linux vol efficiency on -volume XIV2
ssh vsadmin@svm_linux vol efficiency modify -volume XIV2 -inline-compression true -compression true -policy default
ssh vsadmin@svm_linux lun create -path /vol/XIV2/vg5-1 -ostype linux -size 100g -space-reserve disabled
ssh vsadmin@svm_linux lun create -path /vol/XIV2/vg5-2 -ostype linux -size 100g -space-reserve disabled
ssh vsadmin@svm_linux lun create -path /vol/XIV2/vg5-3 -ostype linux -size 100g -space-reserve disabled
ssh vsadmin@svm_linux lun create -path /vol/XIV2/vg6-1 -ostype linux -size 80g -space-reserve disabled
ssh vsadmin@svm_linux lun create -path /vol/XIV2/vg6-2 -ostype linux -size 80g -space-reserve disabled

ssh vsadmin@svm_linux lun map -path /vol/XIV2/vg5-1 -igroup RHEL1
ssh vsadmin@svm_linux lun map -path /vol/XIV2/vg5-2 -igroup RHEL1
ssh vsadmin@svm_linux lun map -path /vol/XIV2/vg5-3 -igroup RHEL1
ssh vsadmin@svm_linux lun map -path /vol/XIV2/vg6-1 -igroup RHEL1
ssh vsadmin@svm_linux lun map -path /vol/XIV2/vg6-2 -igroup RHEL1
