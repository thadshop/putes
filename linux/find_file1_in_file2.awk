# This script check if all lines from file1 exist in exactly the same order
# somewhere in file2.  If so, exit 0, else exit 1.
# usage awk find_file1_in_file2.awk file1 file2
BEGIN { found = 0; line_num = 0; }
NR == FNR { a[NR] = $0; next }
{
    if (a[line_num + 1] == $0) {
        line_num++;
        if (line_num == length(a)) {
            found = 1;
            exit;
        }
    } else {
        line_num = 0; # Reset if the sequence is broken
    }
}
END {
    if (found) {
        exit 0
    } else {
        exit 1
    }
}
