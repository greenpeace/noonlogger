from datetime import datetime,timedelta
import pytz
from tzwhere import tzwhere
import json, os

loc = json.loads(open(os.getcwd()+"/data/position.json","r").read())
print loc

def toMins(dec):
    dec = dec.split(".")
    base = dec[0]
    rest = int(round(float(dec[1]) / (10 ** len(dec[1])) * 60))
    return base+":"+str(rest)

lat = toMins(str(loc[0]))
lon = toMins(str(loc[1]))

elev = 8

tzw = tzwhere.tzwhere(forceTZ=True)
tzs = tzw.tzNameAt(float(loc[0]),float(loc[1]), forceTZ=True)
tz = pytz.timezone(tzs).utcoffset(datetime.utcnow(),is_dst=True)
tzc = pytz.timezone(tzs).tzname(datetime.utcnow(),is_dst=True)
local = datetime.utcnow() + tz 
today = local.replace(hour=0,minute=0,second=0,microsecond=0) - tz

data = {}
data["timezone"] = tzs
data["timecode"] = tzc
data["timedelta"] = tz.seconds / 3600.0

with open(os.getcwd()+"/data/tz.json","w") as file:
    json.dump(data, file)

