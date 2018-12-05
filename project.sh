selection=$(zenity --list "Tebak Nama" "Tetris" --column="" --text="Urutkan Permainan" --title="GameBoy by mchafidha")
if [ "$selection" = "Tebak Nama" ]
	then
	bash tebak.sh
else
	bash tetris.sh
fi

