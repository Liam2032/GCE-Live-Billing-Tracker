## GCE Billing Tracker

<i> Please note: still early work in progress, updating in progress </i>
< br/>
<b> Current support: </b>
Zones: asia-east-1
GPU's: V100, P100, K80 
Storage: SSD, Standard provisioned 

// TODO: other zones, preemptive hardware use. //


This is a simple yet very useful bash script which automatically shows you your current billing cost of a Google Cloud VM Compute instance live and accurately.

What this includes is:
1. Live cost tracking of an instance (based on current exchange rate of chosen currency) 
2. View of past active instance sessions with their cost
3. Automatic system hardware detection for determining accurate billing cost

This is very handy to ensure you don't go over your billing account especially since the billing usage shown by google is 24-48hours delayed.

Feel free to let me know changes/additions to be made :)

### Install:

1. Add following metadata key to your instance:
Key: shutdown-script, Value: sudo dir-of-file/gceshutdown.sh
(where dir-of-file is full working directory of gceshutdown.sh)
(information on how to do this here: https://cloud.google.com/compute/docs/shutdownscript)
2. Run setup.sh (This will create 2 files: one for instance session logging, and one for viewing status
3. Now, you can use gcecosts in the terminal to get an overview of usage.
