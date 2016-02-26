#!/bin/bash

# define query command
osmquery=~/vars/bac/overpass/my_query.sh

# cleanup if something went wrong before
rm reflist.list 2> /dev/null
rm reflist_name_only.list 2> /dev/null
rm sort.tmp 2> /dev/null

# get rooms with ref
$osmquery 'way [level=0][room=yes][ref ~"."]; out;' | grep -e 'k="ref"' -e 'k="name"' > reflist.list

# get rooms without ref
# (when ref data wasn't entered into osm.
#  it should have been, but we also handle the other case)
reflist_name=`$osmquery 'way [level=0][room=yes][name ~"."]; out;' | grep -e 'k="name"'`
cat reflist.list > sort.tmp
echo "$reflist_name" >> sort.tmp
cat "sort.tmp" | sort | uniq -u | grep name > reflist_name_only.list
rm sort.tmp

# backup old db file
if [ -e rooms.json ]; then
    echo "backup old rooms.json"
    num=`ls | grep '^rooms.json' | sed 's/rooms.json//' | sort -V | tail -1`
   if [ "$num" == "" ]; then
        num=1
    else
        num=$(($num + 1))
    fi
    mv rooms.json rooms.json$num
fi

# write db file (json)
echo "processing rooms..."
update_cnt=0
total_cnt_1=`cat reflist.list | grep 'k="ref"' | wc -l`
total_cnt_2=`cat reflist_name_only.list | wc -l`
total_cnt=$(($total_cnt_1 + $total_cnt_2))
name=""

echo '[' > rooms.json
while read line
do
    # grep is slow here (new process for every single line, duh)
    if [ "`echo $line | grep name`" != "" ]; then
        name=`echo $line | sed 's/.*v="\(.*\)".*/\1/'`
    else
        key=`echo $line | sed 's/.*v="\(.*\)".*/\1/'`
        echo "{" >> rooms.json
        echo "\"ref\": \"$key\"," >> rooms.json
        echo "\"name\": \"$name\"," >> rooms.json
        name=""

        # get entrances
        $osmquery "way [ref=\"$key\"]; node(w) [entrance=yes]; out;" > entrances.list
        echo "\"entrances\": [" >> rooms.json
        no_entrances=1
        while read line1
        do
            entrance=`echo $line1 | grep "lat="`
            if [ "$entrance" != "" ]; then
                no_entrances=0
                #entrance=`echo $entrance | sed 's/.*lat="\(.*\)" lon="\(.*\)".*/\1,\2/'`
                lat=`echo $entrance | sed 's/.*lat="\(.*\)" .*/\1'/`
                lon=`echo $entrance | sed 's/.*lon="\(.*\)".*/\1'/`
                #echo "entrance $cnt: $entrance" >> room.list
                echo "{" >> rooms.json
                echo "\"lat\": \"$lat\"," >> rooms.json
                echo "\"lon\": \"$lon\"" >> rooms.json
                echo "}," >> rooms.json
            fi
        done < entrances.list
        if [ $no_entrances -eq 0 ]; then
            sed -i '$ s/.$//' rooms.json # remove the last ',' for entrances
        fi
        echo "]" >> rooms.json
        echo "}," >> rooms.json

        # give status update
        update_cnt=$(($update_cnt +1))
        echo -ne "rooms processed: $update_cnt/$total_cnt"\\r
    fi
done < reflist.list
rm reflist.list

ref=""
while read line
do
    name=`echo $line | sed 's/.*v="\(.*\)".*/\1/'`
    #echo "noref,$name" >> room.list
    echo "{" >> rooms.json
    echo "\"ref\": \"$key\"," >> rooms.json
    echo "\"name\": \"$name\"," >> rooms.json
    # get entrances
    $osmquery "way [name=\"$name\"]; node(w) [entrance=yes]; out;" > entrances.list
    echo "\"entrances\": [" >> rooms.json
    no_entrances=1
    while read line1
    do
        entrance=`echo $line1 | grep "lat="`
        if [ "$entrance" != "" ]; then
            no_entrances=0
            #entrance=`echo $entrance | sed 's/.*lat="\(.*\)" lon="\(.*\)".*/\1,\2/'`
            #echo "entrance $cnt: $entrance" >> room.list
            lat=`echo $entrance | sed 's/.*lat="\(.*\)" .*/\1'/`
            lon=`echo $entrance | sed 's/.*lon="\(.*\)".*/\1'/`
            echo "{" >> rooms.json
            echo "\"lat\": \"$lat\"," >> rooms.json
            echo "\"lon\": \"$lon\"" >> rooms.json
            echo "}," >> rooms.json
        fi
    done < entrances.list
    if [ $no_entrances -ne 1 ]; then
        sed -i '$ s/.$//' rooms.json # remove the last ',' for entrances
    fi
    echo "]" >> rooms.json
    echo "}," >> rooms.json
    update_cnt=$(($update_cnt +1))
    echo -ne "rooms processed: $update_cnt/$total_cnt"\\r
done < reflist_name_only.list
rm reflist_name_only.list
rm entrances.list

sed -i '$ s/.$//' rooms.json # remove the last ',' for rooms
echo "]" >> rooms.json

echo ""
echo "done"
