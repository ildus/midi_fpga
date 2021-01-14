banana pi m1 instructions
===========================

gpio pinout
-------------

	> gpio readall

	+----------+------+------+--------+------+-------+
	|      0   |  17  |  11  | GPIO 0 | ALT4 | Low   |
	|      1   |  18  |  12  | GPIO 1 | IN   | Low   |
	|      2   |  27  |  13  | GPIO 2 | ALT4 | Low   |
	|      3   |  22  |  15  | GPIO 3 | IN   | Low   |
	|      4   |  23  |  16  | GPIO 4 | IN   | Low   |
	|      5   |  24  |  18  | GPIO 5 | IN   | Low   |
	|      6   |  25  |  22  | GPIO 6 | OUT  | Low   |
	|      7   |   4  |   7  | GPIO 7 | IN   | Low   |
	|      8   |   2  |   3  | SDA    | ALT5 | Low   |
	|      9   |   3  |   5  | SCL    | ALT5 | Low   |
	|     10   |   8  |  24  | CE0    | IN   | High  |
	|     11   |   7  |  26  | CE1    | IN   | Low   |
	|     12   |  10  |  19  | MOSI   | IN   | High  |
	|     13   |   9  |  21  | MISO   | IN   | High  |
	|     14   |  11  |  23  | SCLK   | IN   | High  |
	|     15   |  14  |   8  | TxD    | ALT0 | Low   |
	|     16   |  15  |  10  | RxD    | ALT0 | Low   |
	|     17   |  28  |   3  | GPIO 8 | IN   | Low   |
	|     18   |  29  |   4  | GPIO 9 | ALT4 | Low   |
	|     19   |  30  |   5  | GPIO10 | OUT  | High  |
	|     20   |  31  |   6  | GPIO11 | IN   | Low   |
	+----------+------+------+--------+------+-------+

iCE40HX1K-EVB connections
---------------------------

	| bpi m1     |          | ICE40-EVB |              |
	|------------+----------+-----------+--------------|
	|         17 | =3v3=    |         x | =3v3=        |
	|         22 | =gpio6=  |         6 | =creset=     |
	|         19 | =mosi=   |         8 | =sdo=        |
	|         25 | =gnd=    |         2 | =gnd=        |
	|         21 | =miso=   |         7 | =sdi=        |
	|         23 | =clk=    |         9 | =sck=        |
	|         24 | =spi ce0=|        10 | =ss_b=       |

For 3v3 just power from pin 3 of the big connector

commands
--------

	# Pull GPIO6 low to put the ice40 into reset. The cdone-LED on the board should turn off.
	> echo 25 > /sys/class/gpio/export
	> echo out > /sys/class/gpio/gpio25/direction

	# Read the flash chip at 20MHz (for short cabling)
	> gpio load spi
	> flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=20000 -r dump

	# Write
	> flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=20000 -w dump

	As generated bitstreams are smaller than size of the flash chip, you need to add padding for flashrom to accept them as image. I used the follwing commands to do that:

	> tr '\0' '\377' < /dev/zero | dd bs=2M count=1 of=image
	or
	> rm image && truncate -s 2M image
	> dd if=my_bitstream conv=notrunc of=image

	# Deassert creset to let the ice40 read the configuration from the bus:

	> echo in > /sys/class/gpio/gpio25/direction

useful links
-------------

* (Programming under linux)[https://www.olimex.com/wiki/ICE40HX1K-EVB#Get_started_under_Linux]
* (BPI M1 wiki)[http://wiki.banana-pi.org/Banana_Pi_BPI-M1]
