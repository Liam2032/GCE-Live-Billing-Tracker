## GCE Billing Tracker

<i> Please note: still early work in progress, updating in progress </i>
<br/>
<b> Current support: </b>

* Zones: asia-east-1<br/>
* GPU's: V100, P100, K80 <br/>
* Storage: SSD, Standard provisioned 
<br/>

<b> Future Additions: </b>
* Other zone support
* Preemptive hardware pricing

<br/>
<br/>

This is a simple yet very useful bash script which automatically shows you your current billing cost of a Google Cloud VM Compute instance live and accurately.

What this includes is:
1. Live cost tracking of an instance (based on current exchange rate of chosen currency) 
2. View of past active instance sessions with their cost
3. Automatic system hardware detection for determining accurate billing cost

This is very handy to ensure you don't go over your billing account especially since the billing usage shown by google is 24-48hours delayed. <br/>
<b> Please keep in mind costs such as Image storage, Snapshots or internet usage is not monitored and need to also be accounted for </b>
<br/>
<br/>
Feel free to let me know changes/additions to be made :)
<br/>
### Install:
```
1. Add following metadata key to your instance:

Key: shutdown-script
Value: sudo dir-of-file/gceshutdown.sh

(where dir-of-file is full working directory of gceshutdown.sh, information on how to do this here: https://cloud.google.com/compute/docs/shutdownscript)

2. Run gcecost.sh script and follow prompts

3. Restart instance. Now, you can use 'gcecosts' command in terminal with options:
   -v: Verbose mode
   -r: Remove billing history
```
