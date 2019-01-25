### Noon Reports logger with ruby

Automated noon reports flow for Greenpeace ships.

Saves the data to `/var/www/noonlogger/reports/[date].json`

##### Dependencies

Ruby:
- nmea\_plus 
- tcp\_timeout

Python:
- pytz
- tzwhere

##### Instalation

First, install required packages:

```
yum makecache fast
yum install ruby ruby-devel rubygems-devel openssl-devel automake gcc gcc-c++ kernel-devel python2-pip
gem install nmea_plus tcp_timeout
pip install --upgrade pip
pip install pytz tzwhere
```

Clone the repository to `/var/www/noonlogger`, create necessary folders and copy the `editme.rb` file with correct data.

```
cd /var/www/
git clone https://github.com/ta6o/noonlogger.git
cd noonlogger
mkdir data
mkdir reports
cp editme.rb.sample editme.rb
(vim|emacs|nano|etc.) editme.rb
```

Set the cron jobs running with `crontab -e` and append the lines:

```
45 * * * * /usr/bin/python /var/www/noonlogger/tz.py
50 * * * * /usr/bin/ruby /var/www/noonlogger/ais.rb
55 * * * * /usr/bin/ruby /var/www/noonlogger/nmea.rb
```

Make sure that the executables are equipped with the external libraries.


