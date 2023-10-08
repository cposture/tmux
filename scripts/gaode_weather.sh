#!/usr/bin/env bash
# setting the locale, some users have issues with different locales, this forces the correct one
export LC_ALL=en_US.UTF-8

fahrenheit=$1
location=$2
fixedlocation=$3
gaode_map_token=$4
openweather_token=$5
fixed_location_show=$6

current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

getWeather() {
  # 先获取经纬度
  # 接口文档 https://lbs.amap.com/api/webservice/guide/api/georegeo
  geoJSON=$(curl -s "https://restapi.amap.com/v3/geocode/geo?key=$gaode_map_token&address=$fixedlocation")
  rc="$?"
  if [ $rc -ne 0 ]; then
    printf "🌊 weather-error"
    return 1
  fi

  status=$(printf "$geoJSON" | jq -r ".status") # 1 成功
  if [ $status != "1" ]; then
    printf "🌊 weather-error"
    return 1
  fi

  gcjLocation=$(printf "$geoJSON" | jq -r ".geocodes | .[0] | .location") # 返回类似 116.482086,39.990496
  city=$(printf "$geoJSON" | jq -r ".geocodes | .[0] | .city")            # 城市
  district=$(printf "$geoJSON" | jq -r ".geocodes | .[0] | .district")    # 区

  # gcj02 转 wgs84
  wgs84Location=$($current_dir/location_transform/gcj02_to_wgs84 $gcjLocation)

  oldIFS="$IFS" IFS=',' read -ra locations <<< "$wgs84Location" IFS="$oldIFS"
  
  if $fahrenheit; then
    unitsName='standard' # for USA system
  else
    unitsName='metric' # for metric system
  fi

  # 接口文档 https://openweathermap.org/current
  weatherJSON=$(curl -s "https://api.openweathermap.org/data/2.5/weather?lat=${locations[1]}&lon=${locations[0]}&appid=$openweather_token&units=$unitsName")
  rc="$?"
  if [ $rc -ne 0 ]; then
    printf "🌊 weather-error"
    return 1
  fi

  echo $weatherJSON > ~/a.txt

  weatherCode=$(printf "$weatherJSON" | jq -r ".weather | .[0] | .id")  # 天气状况 ID
  weatherDesc=$(printf "$weatherJSON" | jq -r ".weather | .[0] | .description")  # 天气描述
  temperature=$(printf "$weatherJSON" | jq -r ".main.temp") # 当前温度
  sunrise=$(printf "$weatherJSON" | jq -r ".sys.sunrise") # 日升时间
  sunset=$(printf "$weatherJSON" | jq -r ".sys.sunset") # 日落时间
  rain=$(printf "$weatherJSON" | jq -r '.rain["1h"]')
  now=$(date -u +%s)

  if [ $weatherCode == "null" ]; then
    printf "🌊 weather-error"
    return 1
  fi

  # openWeatherMap weather code: https://openweathermap.org/weather-conditions
  awkScript='
        function getMoonEmoji(){
            moonCycle = 2551392           # moon period: 29.53 days, in seconds
            historicalNewMoon = 592500    # 1970-01-07T20:35 
            deltaPhase= now - historicalNewMoon
            currentIntPhase= int((deltaPhase % moonCycle) / moonCycle * 100)
            
            if ( currentIntPhase==0 )
                return "🌑"     # new Moon

            else if ( currentIntPhase>0 && currentIntPhase<25 )
                return "🌒"     # waxing cresent 

            else if ( currentIntPhase==25 )
                return "🌓"     # first quator 

            else if ( currentIntPhase>25 && currentIntPhase<50 )
                return "🌔"     # waxing gibbous     

            else if ( currentIntPhase==50 )
                return "🌕"     # full moon

            else if ( currentIntPhase>50 && currentIntPhase<75 )
                return "🌖"     # waning moon

            else if ( currentIntPhase==75 )
                return "🌗"     # last quator

            else if ( currentIntPhase>75 && currentIntPhase<100 )
                return "🌘"     # waning moon
        }

        function getWeatherEmoji() {
            if (code >= 210 && code <=221)
            # thunderstorm
                return "🌩"        
            
            else if ( (code >= 200 && code <= 202) \
              || (code >= 230 && code <= 232))
            # thunderstorm with rain
                return "⛈️"        
            
            else if (code >= 300 && code <= 321)
            # drizzle 
                return "🌧"
            
            else if (code >= 500 && code <= 531)
            # rain
                return "🌧"
            
            else if (code >= 600 && code<=622)
            # snow
                return "❄️"

            else if (code == 701 || code == 711 || code == 721 || code == 741)
            # mist, smoke, fog, haze ...
                return "🌫"

            else if (code == 781)
            # typhoon
                return "🌀"

            else if (code == 800)
            # clear sky
                return "☀"
            
            else if (code == 801)
            # clouds: 11%-25%
                return "🌤"

            else if (code == 802 || code == 803)
            # clouds: 25%-50% 
            # clouds: 51%-84%
                return "🌥"
           
            else if ( code == 804)
            # clouds: 85%-100%
                return "☁️"
        }

        BEGIN {
            emoji=getWeatherEmoji()
            
            # if the weather condition is great, and it is still night
            if  (( emoji == "☀" || emoji == "🌤" || emoji == "🌥" ) \
              && ( now<= sunrise || now >= sunset ))
                emoji=getMoonEmoji()

            print emoji
        }
    '
    emoji=$(awk -v code="$weatherCode" \
        -v sunrise="$sunrise" -v sunset="$sunset" -v now="$now" \
        "$awkScript")

    width=$(wc -L <<< $emoji)
    prefix=$((3 - $width))
    printf "%s " $emoji
    printf "%*s" $prefix ""
    printf "%s " $weatherDesc
    if [ $rain != "null" ]; then
      printf "%smm " $rain
    fi
    printf "%.0f°C " $temperature
    if [ $fixed_location_show != "" ]; then
      printf $fixed_location_show
    else
      printf $city
      printf $district
    fi
}

get_file_age() { # $1 - cache file
  local file_path="$1"
  local now=$(date +%s)
  local file_modification_timestamp=$(stat -f "%m" "$file_path" 2>/dev/null || echo 0)
  if [ $file_modification_timestamp -ne 0 ]; then
    echo $((now - file_modification_timestamp))
  else
    # return 0 if could not get cache modification time, eg. file does not exist
    echo 0
  fi
}

getWeatherCache() {
  local cache_duration=300
  local cache_path="/tmp/tmux-weather.cache"
  local cache_age=$(get_file_age "$cache_path")
  if ! [ -f "$cache_path" ] || [ $cache_age -ge $cache_duration ]; then
    forecast=$(getWeather)
    rc="$?"
    # 如果调用失败则缓存兜底
    if [ $rc -ne 0 ]; then
      if [ -f "$cache_path" ]; then
        forecast=$(cat "$cache_path" 2>/dev/null)
      fi
    else
      # store forecast in $cache_path
      mkdir -p "$(dirname "$cache_path")"
      echo "$forecast" > "$cache_path"
    fi
  else
    forecast=$(cat "$cache_path" 2>/dev/null)
  fi
  echo "$forecast"
}

main()
{
  echo "$(getWeatherCache)"
}

#run main driver program
main
