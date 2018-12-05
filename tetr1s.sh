#!/bin/bash
set -u # inisialisasi

# SIGUSR1:Menurunkan delay setelah level up & SIGUSR2 keluar
trap '' SIGUSR1 SIGUSR2

#INISIALISASI Controller
QUIT=0
RIGHT=1
LEFT=2
ROTATE=3
DOWN=4
DROP=5
TOGGLE_HELP=6
TOGGLE_NEXT=7
TOGGLE_COLOR=8

DELAY=1          # inisialisasi delay tiap potongan tetris
DELAY_FACTOR=0.8 # nilai awal delay
# kode warna
RED=1
GREEN=2
YELLOW=3
BLUE=4
FUCHSIA=5
CYAN=6
WHITE=7

#Lokasi dan ukuran game, warna bingkai
PLAYFIELD_W=10
PLAYFIELD_H=20
PLAYFIELD_X=30
PLAYFIELD_Y=1
BORDER_COLOR=$YELLOW

# Lokasi dan warna info skor
SCORE_X=1
SCORE_Y=2
SCORE_COLOR=$GREEN

# Lokasi dan warna help
HELP_X=58
HELP_Y=1
HELP_COLOR=$CYAN

# lokasi tetris muncul
NEXT_X=14
NEXT_Y=11

# Lokasi "game over"
GAMEOVER_X=1
GAMEOVER_Y=$((PLAYFIELD_H + 3))

# interval naik speed
LEVEL_UP=20

colors=($RED $GREEN $YELLOW $BLUE $FUCHSIA $CYAN $WHITE)

no_color=true    # memakai warna
showtime=true    # controller runs while this flag is true
empty_cell=" ."  # Gambar tempat kosong
filled_cell="[]" # Gambar tempat terisi

score=0           # inisialisasi skor
level=1           # inisialisasi level
lines_completed=0 # garis terpenuhi

# screen_buffer=variabel,akumulasi perubahan layar
# variabel ini dicetak dalam kontroller sekali tiap putaran game
puts() {
    screen_buffer+=${1}
}

# pindah kursor (x,y) dan cetak string
# (1,1) is upper left corner of the screen
xyprint() {
    puts "\033[${2};${1}H${3}"
}

show_cursor() {
    echo -ne "\033[?25h"
}

hide_cursor() {
    echo -ne "\033[?25l"
}

# warna depan
set_fg() {
    $no_color && return
    puts "\033[3${1}m"
}

# warna belakang
set_bg() {
    $no_color && return
    puts "\033[4${1}m"
}
reset_colors() {
    puts "\033[0m"
}

set_bold() {
    puts "\033[1m"
}
# aplikasi= array 1 dimensi, data disimpan sbb
# [ a11, a21, ... aX1, a12, a22, ... aX2, ... a1Y, a2Y, ... aXY]
#   |<  baris pertama   >|  |<  baris ke2   >|  ... |<  baris terakhir  >|
# X adalah PLAYFIELD_W, Y adalah PLAYFIELD_H
# setiap elemen array mengandung nilai warna sel atau -1 jika sel kosong
redraw_playfield() {
    local j i x y xp yp

    ((xp = PLAYFIELD_X))
    for ((y = 0; y < PLAYFIELD_H; y++)) {
        ((yp = y + PLAYFIELD_Y))
        ((i = y * PLAYFIELD_W))
        xyprint $xp $yp ""
        for ((x = 0; x < PLAYFIELD_W; x++)) {
            ((j = i + x))
            if ((${play_field[$j]} == -1)) ; then
                puts "$empty_cell"
            else
                set_fg ${play_field[$j]}
                set_bg ${play_field[$j]}
                puts "$filled_cell"
                reset_colors
            fi
        }
    }
}

update_score() {
    # Argumen: 1 - jumlah baris selesai
    ((lines_completed += $1))
    # skor bertambah jika jumlah baris selesai
    ((score += ($1 * $1)))
    if (( score > LEVEL_UP * level)) ; then          # jika naik level
        ((level++))                                  # proses naik level
        pkill -SIGUSR1 -f "/bin/bash $0" # mengirim nilai SIGUSR1 ke semua script
    fi
    set_bold
    set_fg $SCORE_COLOR
    xyprint $SCORE_X $SCORE_Y         "Garis terlampaui $lines_completed"
    xyprint $SCORE_X $((SCORE_Y + 1)) "Level:           $level"
    xyprint $SCORE_X $((SCORE_Y + 2)) "Skor:            $score"
    reset_colors
}

help=(
"  Gunakan Kursor"
"       atau"
"      s: up"
"a: kiri,  d: kanan"
"    space: drop"
" q: keluar/selesai"
"  c: toggle color"
"n: ganti selanjutnya"
"h: beralih ke bantuan"
)

help_on=-1 # menampilkan bantuan

toggle_help() {
    local i s

    set_bold
    set_fg $HELP_COLOR
    for ((i = 0; i < ${#help[@]}; i++ )) {
        # jika help_on adalah 1 gunakan string sebagaimana adanya, jika tidak, ganti semua karakter dengan spasi.
        ((help_on == 1)) && s="${help[i]}" || s="${help[i]//?/ }"
        xyprint $HELP_X $((HELP_Y + i)) "$s"
    }
    ((help_on = -help_on))
    reset_colors
}

# array ini menyimpan semua kemungk in an potongan yang bisa digunakan dalam gamegame
# masing-masing terdiri dari 4 sel
# Setiap string adalah urutan koordinat xy relatif untuk orientasi yang berbeda
# tergantung pada simetri potongan bisa ada orientasi 1, 2 atau 4
piece=(
"00011011"                         # potongan kotak
"0212223210111213"                 # garis lurus
"0001111201101120"                 # S
"0102101100101121"                 # Z
"01021121101112220111202100101112" # L
"01112122101112200001112102101112" # invers L
"01111221101112210110112101101112" # T
)

draw_piece() {
    # Argument:
    # 1 - x, 2 - y, 3 - type, 4 - rotation, 5 - cell content
    local i x y

    # loop through piece cells: 4 cells, each has 2 coordinates
    for ((i = 0; i < 8; i += 2)) {
        # relative coordinates are retrieved based on orientation and added to absolute coordinates
        ((x = $1 + ${piece[$3]:$((i + $4 * 8 + 1)):1} * 2))
        ((y = $2 + ${piece[$3]:$((i + $4 * 8)):1}))
        xyprint $x $y "$5"
    }
}

next_piece=0
next_piece_rotation=0
next_piece_color=0

next_on=1 # if this flag is 1 next piece is shown

draw_next() {
    # Arguments: 1 - string to draw single cell
    ((next_on == -1)) && return
    draw_piece $NEXT_X $NEXT_Y $next_piece $next_piece_rotation "$1"
}

clear_next() {
    draw_next "${filled_cell//?/ }"
}

show_next() {
    set_fg $next_piece_color
    set_bg $next_piece_color
    draw_next "${filled_cell}"
    reset_colors
}

toggle_next() {
    case $next_on in
        1) clear_next; next_on=-1 ;;
        -1) next_on=1; show_next ;;
    esac
}

draw_current() {
    # Argumen: 1 - string untuk menggambar sel tunggal
    # faktor 2 untuk x karena masing2 sel berukuran 2 karakter
    draw_piece $((current_piece_x * 2 + PLAYFIELD_X)) $((current_piece_y + PLAYFIELD_Y)) $current_piece $current_piece_rotation "$1"
}

show_current() {
    set_fg $current_piece_color
    set_bg $current_piece_color
    draw_current "${filled_cell}"
    reset_colors
}

clear_current() {
    draw_current "${empty_cell}"
}

new_piece_location_ok() {
    # Arguments: 1 - koordinat x baru dari potongan, 2 - koordinat y baru dari potongan
    # uji jika potongan bisa dipindahkan ke lokasi baru
    local j i x y x_test=$1 y_test=$2

    for ((j = 0, i = 1; j < 8; j += 2, i = j + 1)) {
        ((y = ${piece[$current_piece]:$((j + current_piece_rotation * 8)):1} + y_test)) #koordinat baru y
        ((x = ${piece[$current_piece]:$((i + current_piece_rotation * 8)):1} + x_test)) # koordinat baru x
        ((y < 0 || y >= PLAYFIELD_H || x < 0 || x >= PLAYFIELD_W )) && return 1         #periksa apakah kita berada di luar lapangan bermain
        ((${play_field[y * PLAYFIELD_W + x]} != -1 )) && return 1                       # periksa apakah lokasi sudah terisi
    }
    return 0
}

get_random_next() {
    # bagian yg sedang dieksekusi
    current_piece=$next_piece
    current_piece_rotation=$next_piece_rotation
    current_piece_color=$next_piece_color
    # mengeluarkan potongan, dari tengah dan atas
    ((current_piece_x = (PLAYFIELD_W - 4) / 2))
    ((current_piece_y = 0))
    # periksa apakah potongan bisa ditempatkan di lokasi ini, jika tidak - game over
    new_piece_location_ok $current_piece_x $current_piece_y || cmd_quit
    show_current

    clear_next
    # potongan selanjutnya
    ((next_piece = RANDOM % ${#piece[@]}))
    ((next_piece_rotation = RANDOM % (${#piece[$next_piece]} / 8)))
    ((next_piece_color = RANDOM % ${#colors[@]}))
    show_next
}

draw_border() {
    local i x1 x2 y

    set_bold
    set_fg $BORDER_COLOR
    ((x1 = PLAYFIELD_X - 2))               # border= 2 karakter
    ((x2 = PLAYFIELD_X + PLAYFIELD_W * 2)) # tempat game= 2 kotak luasan
    for ((i = 0; i < PLAYFIELD_H + 1; i++)) {
        ((y = i + PLAYFIELD_Y))
        xyprint $x1 $y "<|"
        xyprint $x2 $y "|>"
    }

    ((y = PLAYFIELD_Y + PLAYFIELD_H))
    for ((i = 0; i < PLAYFIELD_W; i++)) {
        ((x1 = i * 2 + PLAYFIELD_X)) # sel lapangan=2 karakter
        xyprint $x1 $y '=='
        xyprint $x1 $((y + 1)) "\/"
    }
    reset_colors
}

toggle_color() {
    $no_color && no_color=false || no_color=true
    show_next
    update_score 0
    toggle_help
    toggle_help
    draw_border
    redraw_playfield
    show_current
}

init() {
    local i x1 x2 y

    # game tetris diinisialisasi dengan -1s (sel kosong)
    for ((i = 0; i < PLAYFIELD_H * PLAYFIELD_W; i++)) {
        play_field[$i]=-1
    }

    clear
    hide_cursor
    get_random_next
    get_random_next
    toggle_color
}

# Ini akan mengir in kan perintah DOWN ke controller dengan delay yang sesuai
ticker() {
    # pada SIGUSR2 proses ini harus keluar
    trap exit SIGUSR2
    #SIGUSR1 (delay) harus diturunkan, hal ini terjadi level up
    trap 'DELAY=$(awk "BEGIN {print $DELAY * $DELAY_FACTOR}")' SIGUSR1

    while true ; do echo -n $DOWN; sleep $DELAY; done
}

# memproses input keyboard
reader() {
    trap exit SIGUSR2 # keluar dari SIGUSR2
    trap '' SIGUSR1   # SIGUSR1 diabaikan
    local -u key a='' b='' cmd esc_ch=$'\x1b'
    # memetakan kunci yang ditekan ke perintah, dikirim ke pengontrol
    declare -A commands=([A]=$ROTATE [C]=$RIGHT [D]=$LEFT
        [_S]=$ROTATE [_A]=$LEFT [_D]=$RIGHT
        [_]=$DROP [_Q]=$QUIT [_H]=$TOGGLE_HELP [_N]=$TOGGLE_NEXT [_C]=$TOGGLE_COLOR)

    while read -s -n 1 key ; do
        case "$a$b$key" in
            "${esc_ch}["[ACD]) cmd=${commands[$key]} ;; # kursor
            *${esc_ch}${esc_ch}) cmd=$QUIT ;;           # exit
            *) cmd=${commands[_$key]:-} ;;       
esac       
        b=$key
        [ -n "$cmd" ] && echo -n "$cmd"
    done
}

# fungsi ini memperbarui sel yang diduduki dalam array play_field setelah potongan dijatuhkan
flatten_playfield() {
    local i j k x y
    for ((i = 0, j = 1; i < 8; i += 2, j += 2)) {
        ((y = ${piece[$current_piece]:$((i + current_piece_rotation * 8)):1} + current_piece_y))
        ((x = ${piece[$current_piece]:$((j + current_piece_rotation * 8)):1} + current_piece_x))
        ((k = y * PLAYFIELD_W + x))
        play_field[$k]=$current_piece_color
    }
}

# eliminasi garis yang benar2 terisi penuh
process_complete_lines() {
    local j i complete_lines
    ((complete_lines = 0))
    for ((j = 0; j < PLAYFIELD_W * PLAYFIELD_H; j += PLAYFIELD_W)) {
        for ((i = j + PLAYFIELD_W - 1; i >= j; i--)) {
            ((${play_field[$i]} == -1)) && break # empty cell found
        }
        ((i >= j)) && continue # Loop sebelumnya terganggu karena sel kosong ditemukan
        ((complete_lines++))
        # pindah ke garis bawah
        for ((i = j - 1; i >= 0; i--)) {
            play_field[$((i + PLAYFIELD_W))]=${play_field[$i]}
        }
        # menandai sel bebas
        for ((i = 0; i < PLAYFIELD_W; i++)) {
            play_field[$i]=-1
        }
    }
    return $complete_lines
}

process_fallen_piece() {
    flatten_playfield
    process_complete_lines && return
    update_score $?
    redraw_playfield
}

move_piece() {
# argumen: 1 - x koordinat baru, 2 - y koordinat baru
# memindahkan potongan ke lokasi baru jika memungkinkan
    if new_piece_location_ok $1 $2 ; then # jika lokasinya ok
        clear_current                     # hapus
        current_piece_x=$1                # update x ...
        current_piece_y=$2                # ... dan y utk lokasi baru
        show_current                      # gambar bagian di lokasi baru
        return 0                          
    fi                                    # jika kita tidak bisa pindah ke lokasi baru
    (($2 == current_piece_y)) && return 0 # dan bukan horizontal
    process_fallen_piece                  
    get_random_next                       # dan mulai baru lagi
    return 1
}

cmd_right() {
    move_piece $((current_piece_x + 1)) $current_piece_y
}

cmd_left() {
    move_piece $((current_piece_x - 1)) $current_piece_y
}

cmd_rotate() {
    local available_rotations old_rotation new_rotation

    available_rotations=$((${#piece[$current_piece]} / 8))            
    old_rotation=$current_piece_rotation                              
    new_rotation=$(((old_rotation + 1) % available_rotations))        
    current_piece_rotation=$new_rotation                             
    if new_piece_location_ok $current_piece_x $current_piece_y ; then
        current_piece_rotation=$old_rotation                          
        clear_current                                                
        current_piece_rotation=$new_rotation                       
        show_current                                                  
    else                                                             
        current_piece_rotation=$old_rotation                         
    fi
}

cmd_down() {
    move_piece $current_piece_x $((current_piece_y + 1))
}

cmd_drop() {
    # move piece all way down
    # this is example of do..while loop in bash
    # loop body is empty
    # loop condition is done at least once
    # loop runs until loop condition would return non zero exit code
    while move_piece $current_piece_x $((current_piece_y + 1)) ; do : ; done
}

cmd_quit() {
    showtime=false                               # stop permainan
    pkill -SIGUSR2 -f "/bin/bash $0" # stop SIGUSR2
    xyprint $GAMEOVER_X $GAMEOVER_Y "Permainan Selesai!"
    echo -e "$screen_buffer"                     #cek pesan trakhir
}

controller() {
    # SIGUSR1 & SIGUSR2 diabaikan
    trap '' SIGUSR1 SIGUSR2
    local cmd commands

    # initialization of commands array with appropriate functions
    commands[$QUIT]=cmd_quit
    commands[$RIGHT]=cmd_right
    commands[$LEFT]=cmd_left
    commands[$ROTATE]=cmd_rotate
    commands[$DOWN]=cmd_down
    commands[$DROP]=cmd_drop
    commands[$TOGGLE_HELP]=toggle_help
    commands[$TOGGLE_NEXT]=toggle_next
    commands[$TOGGLE_COLOR]=toggle_color

    init

    while $showtime; do           # dijalankan dan diberi true, diubah menjadi false dalam fungsi cmd_quit.
        echo -ne "$screen_buffer" # output screen buffer
        screen_buffer=""          # reset
        read -s -n 1 cmd          # read next command from stdout
        ${commands[$cmd]}         # run command
    done
}

stty_g=`stty -g` # simpen status terminal

# output ticker dan reader digabung ke kontroller
(
    ticker & # ticker jalan sebagai proses pemisah
    reader
)|(
    controller
)
show_cursor
stty $stty_g # mengembalikan status terminal