## GCE Billing Tracker 
### Now With GDRIVE Support!
<i> Please note: still early work in progress, updating in progress </i>
<br/>
<b> Current support: </b>

* Zones: asia-east-1<br/>
* GPU's: V100, P100, K80 <br/>
* Storage: SSD, Standard provisioned  <br/>
##### Features
1. Integration with gdrive for live tracking accross all account VM's
2. Show real-time cost of resources based on latest exchange rates and hardware costs
2. View all past or current VM billing sessions
3. Syncs automatically every 60 minutes. Pushes on shutdown final VM usage and pulls history from cloud.
4. See what you are actually using and not estimate based off a 24-48hour delay!
5. Calculates automatically from used system hardware what total cost of usage is per session.

<br/>

This is a very useful bash script which automatically shows you your current billing cost of your Google Cloud VM Compute instances live and accurately.

If you care about your money and want a live view of your usage, try this out! <br/>
<b> Please keep in mind costs such as Image storage, Snapshots or internet usage is not monitored and need to also be accounted for </b>
<br/>
<br/>
Feel free to let me know changes/additions to be made :)
<br/>
### Install:
```
1. Run gcecosts.sh. This will walk you though setup of gdrive, authentication and everything else.
2. Important: setup will require you to add a shutdown Meta key for each VM. Please do this and follow instructions...
3. After completed setup, you will have access to VM tracking and features.

Run: gcecosts [options]
   [-v]: Verbose mode / print out detailed history and cost usage
   [-s]: sync latest VM billing history from cloud to local instance / push current VM usage
   [-r]: Reset environment
```
