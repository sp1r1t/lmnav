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
if [ -e room.list ]; then
    echo "backup old room.list"
    num=`ls | grep '^room.list' | sed 's/room.list//' | sort -V | tail -1`
   if [ "$num" == "" ]; then
        num=1
    else
        num=$(($num + 1))
    fi
    mv room.list room.list$num
fi

# write db file
echo "processing rooms..."
update_cnt=0
total_cnt_1=`cat reflist.list | grep 'k="ref"' | wc -l`
total_cnt_2=`cat reflist_name_only.list | wc -l`
total_cnt=$(($total_cnt_1 + $total_cnt_2))
name=""

while read line
do
    # grep is slow here (new process for every single line, duh)
    if [ "`echo $line | grep name`" != "" ]; then
        name=`echo $line | sed 's/.*v="\(.*\)".*/\1/'`
    else
        key=`echo $line | sed 's/.*v="\(.*\)".*/\1/'`
        if [ "$name" != "" ]; then
            echo "$key,$name" >> room.list
            name=""
        else
            echo "$key" >> room.list
        fi
        # get entrances
        entrances=`$osmquery "way [ref=\"$key\"]; node(w) [entrance=yes]; out;"`
        cnt=1
        echo "$entrances" | while read line1
        do
            entrance=`echo $line1 | grep "lat="`
            if [ "$entrance" != "" ]; then
                entrance=`echo $entrance | sed 's/.*lat="\(.*\)" lon="\(.*\)".*/\1,\2/'`
                echo "entrance $cnt: $entrance" >> room.list
                cnt=$(($cnt + 1))
            fi
        done
        update_cnt=$(($update_cnt +1))
        echo -ne "rooms processed: $update_cnt/$total_cnt"\\r
    fi
done < reflist.list
rm reflist.list

while read line
do
    name=`echo $line | sed 's/.*v="\(.*\)".*/\1/'`
    echo "noref,$name" >> room.list
    # get entrances
    entrances=`$osmquery "way [name=\"$name\"]; node(w) [entrance=yes]; out;"`
    cnt=1
    echo "$entrances" | while read line1
    do
        entrance=`echo $line1 | grep "lat="`
        if [ "$entrance" != "" ]; then
            entrance=`echo $entrance | sed 's/.*lat="\(.*\)" lon="\(.*\)".*/\1,\2/'`
            echo "entrance $cnt: $entrance" >> room.list
            cnt=$(($cnt + 1))
        fi
    done
    update_cnt=$(($update_cnt +1))
    echo -ne "rooms processed: $update_cnt/$total_cnt"\\r
done < reflist_name_only.list
rm reflist_name_only.list

echo ""
echo "done"
