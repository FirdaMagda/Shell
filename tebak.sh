function wrong1 {
    echo
    echo "        O             "
    echo
    echo
    echo
    echo
    echo
    echo
}
function wrong2 {
    echo
    echo "         O            "
    echo "         |            "
    echo
    echo
    echo
    echo
    echo
}
function wrong3 {
    echo
    echo "         O            "
    echo "         |\           "
    echo
    echo
    echo
    echo
    echo
}
function wrong4 {
    echo
    echo "         O            "
    echo "        /|\           "
    echo
    echo
    echo
    echo
    echo
}
function wrong5 {
    echo
    echo "         O            "
    echo "        /|\           "
    echo "        /             "
    echo
    echo
    echo
    echo
}
function wrong6 {
    echo
    echo "         O            "
    echo "        /|\           "
    echo "        / \           "
    echo
    echo
    echo
    echo
}
function wrong7 {
    echo
    echo "         __________   "
    echo "         |        |   "
    echo "         O        |   "
    echo "        /|\       |   "
    echo "        / \       |   "
    echo "    ______________|___"
    echo
}

function display {
    DATA[0]=""
    echo


 
    REAL_OFFSET_X=$(($((`tput cols` - 56)) / 2))
    REAL_OFFSET_Y=$(($((`tput lines` - 6)) / 2))

    draw_char() {
        V_COORD_X=$1
        V_COORD_Y=$2

        tput cup $((REAL_OFFSET_Y + V_COORD_Y)) $((REAL_OFFSET_X + V_COORD_X))

        printf %c ${DATA[V_COORD_Y]:V_COORD_X:1}
    }

    trap 'exit 1' INT TERM

    tput civis
    clear
    tempp=1
    while :; do
        tempp=`expr $tempp - 1`
        for ((c=1; c <= 1; c++)); do
            tput setaf 2 #warna font
            for ((x=0; x<${#DATA[0]}; x++)); do
                for ((y=0; y<=1; y++)); do
                    draw_char $x $y
                done
            done
        done
        sleep 1
        clear
        break
    done
}

function menu() {
    exec 2> /dev/null
    ## layar awal
    selection=$(zenity --list "Tebak Nama MHS D4TA16" "Tentang D4TA16" "Exit" --column="" 
	--text="Silahkan Pilih:" --title="Kenal D4TA16 yuk!" --cancel-label="Quit")
    case "$selection" in
        "Tebak Nama MHS D4TA16") main;;
        "Tentang D4TA16") choice;;
        "Exit") exit;;
    esac
    echo
}
##tentang
function choice() {
    choose=$(zenity --info --text="D4TA16 adalah definisi
	dari sebuah keluarga. InsyaAllah 30/30 sampai lulus, aamiin" --title="Tentang")
    menu
}

function main() {
    ##membaca list kata
    readarray a < $filename

    randind=`expr $RANDOM % ${#a[@]}`

    nama=${a[$randind]}

    guess=()

    guesslist=()
    guin=0

    nama=`echo $nama | tr -dc '[:alnum:] \n\r' | tr '[:upper:]' '[:lower:]'`
    len=${#nama}

    for ((i=0;i<$len;i++)); do
        guess[$i]="_"
    done

    mov=()

    for ((i=0;i<$len;i++)); do
        mov[$i]=${nama:$i:1}
        # echo -n "${mov[$i]} "
    done

    for ((j=0;j<$len;j++)); do
        if [[ ${mov[$j]} == " " ]]; then
            guess[$j]=" "
        fi
    done

    ## Tampilan inisialisasi salah
    wrong=0

    while [[ $wrong -lt 7 ]]; do
        case $wrong in
            0)echo " "
            ;;
            1)wrong1
            ;;
            2)wrong2
            ;;
            3)wrong3
            ;;
            4)wrong4
            ;;
            5)wrong5
            ;;
            6)wrong6
            ;;
        esac

        if [[ wrong -eq 0 ]]; then
            for i in {1..7}
            do
                echo
            done
        fi

        notover=0
        for ((j=0;j<$len;j++)); do
            if [[ ${guess[$j]} == "_" ]]; then
                notover=1
            fi
        done

        echo  Daftar huruf yang sudah dicoba: ${guesslist[@]}
        echo Jumlah salah: $wrong
        for ((k=0;k<$len;k++)); do
            echo -n "${guess[$k]} "
        done
        echo
        echo

        if [[ notover -eq 1 ]]; then
            echo -n "Tebak nama: "
            read -n 1 -e letter
            letter=$(echo $letter | tr [A-Z] [a-z])
            guesslist[$guin]=$letter
            guin=`expr $guin + 1`
        fi

        f=0;
        for ((i=0;i<$len;i++)); do
            if [[ ${mov[$i]} == $letter ]]; then
                guess[$i]=$letter
                f=1
            fi
        done
        if [[ f -eq 0 ]]; then
            wrong=`expr $wrong + 1`
        fi

        if [[ notover -eq 0 ]]; then
            echo
            echo You Win!
            echo $nama
            echo
            play_again
        fi
        clear
    done

    wrong7
    echo Kamu kalah!
    echo Namanya adalah: $nama
    play_again
}

function play_again(){
    echo
    echo -n "Mau main lagi? (y/t) "
    read -n 1 choice
    case $choice in
        [yY]) clear
              main 
        ;;
    esac
    clear
    echo "Terimakasih telah bermain!"
    tput cnorm
    exit
}

function init(){
    clear
    ##import file
    filename="nama"
    
    echo
    display
    
    menu
}

init
