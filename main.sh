# echo '国名符号,国名,通貨,ISO,当該通貨1単位につき(円),当該通貨100単位につき(円)' > file_name.csv
# cat target_file | sed 's/ \+/,/g' | awk 'NF>0' | sed 's/^,//' | grep '^[0-9]' | grep -v '年' >> file_name.csv

# mkfifo tmp
# cat $1 | grep '304' | awk '{print $5}' > tmp | basename kouji-rate20200920-20200926.txt .txt | sed -e 's/kouji-rate\(.*\)-\(.*\)/\1,\2/' > tmp | cat tmp | tr '\n' ',' > usdrate.csv

set -ue

prepare(){
    # -p = no error if existing
    mkdir -p raw-date/
    mkdir -p pdf-renamed/
    mkdir -p txt-converted/
}

initialize() {
    rm -rf txt-converted/
}

download() {
    curl wget -r -l 1 -A.pdf -nd https://www.customs.go.jp/tetsuzuki/kawase/list.htm
    curl wget -r -l 1 -A.pdf -nd https://www.customs.go.jp/tetsuzuki/kawase/index.htm
    mv *.pdf ./raw-data
}


convert() {
    for pdf_file in ./pdf-renamed/*.pdf; do
        # get filename + extension
        pdf_file_ext="${pdf_file##*/}"
        # get filename only
        pdf_file_name="${pdf_file_ext%.*}"

        if [ -e ./txt-converted/$pdf_file_name.txt ]; then
            echo "$pdf_file_name is already converted, skip"
        else
            echo converting $pdf_file to txt
            pdftotext -layout $pdf_file ./txt-converted/$pdf_file_name.txt
        fi
    done
}

copy_rate() {
    echo date,end-date,period,usdjpy-rate > usdjpy-rate-history-tmp.csv
    for txt_file in ./txt-converted/*.txt; do
        # get filename + extension
        txt_file_ext="${txt_file##*/}"
        # get filename only
        txt_file_name="${txt_file_ext%.*}"

        echo "extracting $txt_file_name and copying data to csvfile"

        # format date
        rate=$(cat $txt_file | grep '304' | awk '{print $5}')
        start_date=$(basename $txt_file .txt | perl -pe 's/(\d{4})(\d{2})(\d{2})-(\d{4})(\d{2})(\d{2})/$1\/$2\/$3/')
        end_date=$(basename $txt_file .txt | perl -pe 's/(\d{4})(\d{2})(\d{2})-(\d{4})(\d{2})(\d{2})/$4\/$5\/$6/')

        # calc Period
        start_date_unix_time=$(date -d "$start_date" +%s)
        end_date_unix_time=$(date -d "$end_date" +%s)
        period=$((($end_date_unix_time - start_date_unix_time) /60 /60 /24))

        echo $start_date,$end_date,$period,$rate >> usdjpy-rate-history-tmp.csv
    done
}

format() {
    echo formatting
    cat usdjpy-rate-history-tmp.csv | sed -e 's/ /,/' | awk -F',' '{print $1","$2","$3","$4}' \
        | awk -F',' '{print $1","$4} {print $2","$4}' | sed 2d > usdjpy-rate-history.csv
    echo exported usdjpy-rate-history
    rm usdjpy-rate-history-tmp.csv
    echo finish
}

# download
# initialize
prepare
convert
copy_rate
format
