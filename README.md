
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![version](https://img.shields.io/badge/version-1.0-green)

# DoodleJump-Assembly

## Introduction

DoodleJump-Assembly is an implementation of the vertical scroller game "Doodle Jump" written in assembly (MIPS), using the MARS simulator.

It is designed to output to a bitmap array. A visual example of this can be seen using the MARS simulator's bitmap display (and the keyboard and display mmio simulator to accept user input).

## Application Features

This application allows you to play a simple Doodle Jump game, controlled by keyboard. It has 3 main screens, the welcome screen, main game screen, and ending screen.

The welcome screen await user input; a name of 6 characters is required upon which the game will start. Valid keypresses are [0-9,A-Z,a-z,space].

![DoodleJump-Assembly-welcome_screen](images/welcome_screen.jpg)

During the main gameloop press j/k to move to player character left/right. As the player ascends platforms, the score will increment. By default the winning score is 100.

![DoodleJump-Assembly-game_screen](images/game_screen.jpg)

Upon falling off the platforms, the game will end and display either a victory or loss screen.

![DoodleJump-Assembly-ending_screen](images/ending_screen.jpg)

## License

This project is licensed under the [MIT License](LICENSE).

