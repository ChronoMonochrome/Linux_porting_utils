#
# Resolve merge conflict
# Args:
#    $1: path to ours.txt file
#    $2: path to theirs.txt file
# each line in {ours,theirs}.txt must represent a path to file(s)
# to reset (git checkout --ours / --theirs) to ours / theirs.
#
resolve_conflicts()
{
   OURS=$1
   THEIRS=$2

   if [ -z $OURS ] ; then
       return
   fi

   ours=$(cat $OURS)
   theirs=$(cat $THEIRS)

   git_cleanup
   echo ours

   if [ ! -z "$ours" ] ; then
       for d in $ours;
       do
           git checkout HEAD 2>/dev/null -- $d
       done
   fi

   echo THEIRS

   if [ -z $THEIRS ] ; then
       return
   fi

   echo theirs

   for d in $theirs;
   do
       git checkout --theirs 2>/dev/null -- $d
       git add $d
   done
}

#
# Cherry-pick a set of commits
# Args:
#   $1: path to file containing set of commits.
#       This file must be produced by
#	"git log --oneline {REV1}...{REV2}"
#
cherrypick_v2()
{
    IN_FILE=$1
    tac $IN_FILE | while read -r line; do
         commit=$(echo $line | cut -d " " -f1)
         git cherry-pick $commit
         if [ $? -ne 0 ] ; then
             resolve_conflicts ours.txt theirs.txt
             found=0
             for i in `unmerged`
             do
                 found=1
                 break
             done
             if [ $found -eq 1 ] ; then
                 break
             fi

             git commit -a --no-edit
         fi
         head -n -1 $IN_FILE > temp.txt ; mv temp.txt $IN_FILE
    done
}

#
# Merge a set of commits
# Args:
#   $1: path to file containing set of commits.
#       This file must be produced by
#	"git log --oneline --merges --ancestry-path {REV1}...{REV2}"
#
merge_v2()
{
    IN_FILE=$1
    tac $IN_FILE | while read -r line; do
         commit=$(echo $line | cut -d " " -f1)
         git merge $commit --no-edit
         if [ $? -ne 0 ] ; then
             test -f theirs.sh && bash theirs.sh
             test -f ours.sh && bash ours.sh
             found=0
             for i in `unmerged`
             do
                 if [ $(grep -c "<<<<" "$i") -ge 1 ] ; then
                     found=1
                     break
                 fi
             done
             if [ $found -eq 1 ] ; then
                 break
             fi

             git commit -aC $commit --no-edit
         else
             git commit -aC $commit --no-edit --amend
         fi
         head -n -1 $IN_FILE > temp.txt ; mv temp.txt $IN_FILE
    done
}

modified()
{
	git diff --name-only --diff-filter=M
}

added()
{
	git diff --name-only --diff-filter=A
}

deleted()
{
	git diff --name-only --diff-filter=D
}

unmerged()
{
        git diff --name-only --diff-filter=U
}

ours() {
	rtof HEAD $(unmerged)
}

files() {
    view $1 --stat=300 | head -n -1 | cut -d "|" -f1 | xargs
}

commit_name()
{
	git log --oneline "$1" | head -n1 | cut -d " " -f2-
}

# remove junk files left after merge conflicts
clean()
{
	find . -name "*.rej" -o -name "*.orig" -o -name "*_BASE_*" -o -name "*_BACKUP_*" -o -name "*_REMOTE_*" -o -name "*_LOCAL_*" | xargs -L1 rm
}

# get amount of commits between rev1 and rev2
check_count() {
 git log --oneline $1...$2 | wc -l
}

checkout() {
 base_branch=$1
 commit=$2
 git checkout -b $base_branch+`check_count $base_branch $commit` $commit
}

# to clear rr-cache
#grep -Rn drm .git/rr-cache/ | cut -d ":" -f1 | grep -o '.*/' | uniq
