# WEBSITE PREPARATION:
#  every time some new elements are added/changed in the CSV dataset
#  (with their related *.png ),
#  Run this script.
#   This scripts rebuilds the static website and starts a local webserver.
#   If everything seems working, then commit the changes on Github Pages.

# ==============================================================================
set DATASET  "_data/cards.csv"
set CARD_DIR "_cards"
set IMAGE_DIR "pics"
set THUMB_HEIGHT 100



package require csv

 # --
 # get a full complete CSV line, split it and return its field-values
 # --
proc _getAndSplitCSVline {f {multilineSubString "\n"}} {
	set completeLine ""
	while {true} {
		set line [gets $f]
		if { $completeLine == "" } {
			append completeLine $line
		} else {
			append completeLine $multilineSubString $line
		}
		if { [csv::iscomplete $completeLine] } break
		if { [eof $f] } break
	}
	return [csv::split $completeLine]
}

# ===
# == load CSV dataset; sort by ID
# ===
set table {}
set f [open $DATASET "r"]
fconfigure $f -encoding utf-8

# -- read the header
set columns [_getAndSplitCSVline $f]

# expected columns are (in this order):
#   ID SOURCE TITLE INFO RELATED

# check
set eColumns {ID SOURCE TITLE INFO RELATED}
if { $columns != $eColumns } {
	error "actual columns: <<$columns>> ; expected <<$eColumns>>"
}

while { ![eof $f] } {
	set row [_getAndSplitCSVline $f]
	if { $row eq {} } continue
	lappend table $row
}
close $f

# sort table on the 0th column (column "ID")
set table [lsort -index 0 $table]

set IDs [lmap row $table { lindex $row 0 }]

# ==
# == foreach ID set its prev/next ID  ("" if first/last)
# ==
set nextIDs [lrange $IDs 1 end] ; lappend nextIDs {}
set prevIDs {}
lappend prevIDs {} ; lappend prevIDs {*}[lrange $IDs 0 end-1]


# == foreach ID create <destDir>/<ID>.md with the following front-matter:
# ---
# ID: ...
# seqNo: ..
# title:
# detail:
# relIDS:
# -----
set seqNo 0
foreach row $table nextID $nextIDs prevID $prevIDs {
	lassign $row {*}$columns

	# plus: check if RELATED ids are correct
	foreach id [split $RELATED " "] {
		if { $id ni $IDs } {
			puts stderr "WARNING: ID \"$ID\" has a broken reference to id \"$id\""
		}
	}

	set f [open ${CARD_DIR}/${ID}.md w]
		puts $f "---"
		puts $f "ID: $ID"
		puts $f "SOURCE: \"$SOURCE\""
		puts $f "TITLE: \"$TITLE\""
		puts $f "INFO: \"$INFO\""
		puts $f "RELATED: \"$RELATED\""
		puts $f "seqNo: $seqNo"
		puts $f "prevID: $prevID"
		puts $f "nextID: $nextID"
# ..ecc ecc
		puts $f "---"
	close $f

	incr seqNo
}

package require tclBlend2d

# ==
# == foreach ID check if <imageDir>/<ID>.png  exist ! --> error
# ==  and create a thumbnail <ID>_t.png if it does not exist (height:200 , width : ..scaled)
# ==
proc resizeImage {filename newH newFilename} {
	set sfc [BL::Surface new]
	$sfc load $filename
	lassign [$sfc size] W H
	set newW [expr {round($W*($newH/double($H)))}]
	set newSfc [BL::Surface new -format [list $newW $newH]]
	$newSfc clear
	$newSfc rawcopy $sfc -to [list 0 0 $newW $newH]
	$newSfc save $newFilename
	$newSfc destroy
	$sfc destroy
}

set someErrors false
foreach row $table {
	lassign $row ID
	set imgFile $IMAGE_DIR/${ID}.png
	if { [file exists $imgFile] } {
		set thumbFile $IMAGE_DIR/${ID}_t.png
		if { ! [file exists $thumbFile] } {
			try {
		  		resizeImage $imgFile $THUMB_HEIGHT $thumbFile
			} on error e {
				puts stderr "WARNING: cannot create thumbnail for $imgFile"
                set someErrors true
			}
		}
	} else {
		puts stderr "WARNING: missing file \"$imgFile\""
		set someErrors true
	}
}
if {$someErrors} exit

# == build and serve ..
puts "=== Running \"bundle exec jekyll serve\""
exec bundle exec jekyll serve
