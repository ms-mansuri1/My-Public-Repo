#!/bin/bash
dry_run=0
echo_progress=1

d=$(date +'%Y-%m-%d' -d '1 day ago')
if [ $echo_progress -eq 1 ]
then
  echo "Date of snapshots to delete (if older than): $d"
fi

snapshots_to_delete=$(aws ec2 describe-snapshots \
    --owner-ids 371152315633 \
    --output text \
    --query "Snapshots[?StartTime<'$d'].SnapshotId" \
)
if [ $echo_progress -eq 1 ]
then
  echo "List of snapshots to delete: $snapshots_to_delete"
fi

for oldsnap in $snapshots_to_delete; do

  # some $oldsnaps will be in use, so you can't delete them
  # for "snap-a1234xyz" currently in use by "ami-zyx4321ab"
  # (and others it can't delete) add conditionals like this

  if [ "$oldsnap" = "snap-0dc6b6ad009f3e9b9" ] ||
     [ "$oldsnap" = "snap-018f0920e4609c47d" ] ||
     [ "$oldsnap" = "snap-0a50ba7d31e038e53" ] ||
     [ "$oldsnap" = "snap-046e5ba5aaa374904" ] ||
     [ "$oldsnap" = "snap-00441faa7b0c933d7" ] ||
     [ "$oldsnap" = "snap-0b3f49a9562aec5da" ] ||
     [ "$oldsnap" = "snap-05489a1d590894d17" ] ||
     [ "$oldsnap" = "snap-0d0138f9a74d82933" ] ||
     [ "$oldsnap" = "snap-023e4f476984ae28f" ] ||
     [ "$oldsnap" = "snap-0866c458a34c29163" ] ||
         [ "$oldsnap" = "snap-00c8910c8407b51c1" ]
 then
    if [ $echo_progress -eq 1 ]
    then
       echo "skipping $oldsnap known to be in use by an ami"
    fi
    continue
  fi

  if [ $echo_progress -eq 1 ]
  then
     echo "deleting $oldsnap"
  fi

  if [ $dry_run -eq 1 ]
  then
    # dryrun will not actually delete the snapshots
    aws ec2 delete-snapshot --snapshot-id $oldsnap --dry-run
  else
    aws ec2 delete-snapshot --snapshot-id $oldsnap
  fi
done
