mkdir $1
for i in `find . -iname $1\*`; do
    cp $i/*peer* $1
done
