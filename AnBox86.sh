#!/bin/bash

### AnBox86.sh
# Authors: lowspecman420, WheezyE
#
# This script is made to be run by the Termux app (for Android devices).  It is recommended you download Termux from F-Droid rather than from the Google Play Store.
# This script will install a PRoot guest system (Ubuntu 20.04) in Termux.  Then it will install box86 and wine-i386 on that guest system.
# Note that this script uses tabs (	) instead of spaces ( ) for formatting since parts of this script use heredoc (i.e. eom & eot).
#

function run_Main()
{
	rm -f AnBox86.sh # sliently self-destruct (since this script should only be run once) just in case the user ran this script by downloading it
	
        # Enable left & right keys in Termux (optional) - https://www.learntermux.tech/2020/01/how-to-enable-extra-keys-in-termux.html
	mkdir $HOME/.termux/
	echo "extra-keys = [['ESC','/','-','HOME','UP','END'],['TAB','CTRL','ALT','LEFT','DOWN','RIGHT']]" >> $HOME/.termux/termux.properties
	termux-reload-settings
	#termux-setup-storage # So we can access the sd card
	
	# Update Termux source lists (just in case Termux was downloaded from Google Play Store instead of from F-Droid)
	#  - Termux source list mirrors are located here: https://github.com/termux/termux-app#google-playstore-deprecated
	echo "deb https://termux.mentality.rip/termux-main stable main" > $PREFIX/etc/apt/sources.list 
	echo "deb https://termux.mentality.rip/termux-games games stable" > $PREFIX/etc/apt/sources.list.d/game.list
	echo "deb https://termux.mentality.rip/termux-science science stable" > $PREFIX/etc/apt/sources.list.d/science.list
	pkg update -y -o Dpkg::Options::=--force-confnew && pkg upgrade -y -o Dpkg::Options::=--force-confnew # upgrade Termux and suppress user prompts 
	
	# Create the Ubuntu PRoot within Termux
	# - And initialize paths for our Termux shell instance (also add them to .bashrc for future Termux shell instances)
	pkg install proot-distro git -y
	cp $PREFIX/etc/proot-distro/ubuntu.sh $PREFIX/etc/proot-distro/ubuntu-arm.sh
	# TODO: SED to add DISTRO_ARCH="arm"
	proot-distro install ubuntu-arm
	git clone https://github.com/ZhymabekRoman/proot-static # Use a 32bit PRoot instead of 64bit
	
	# Create a script to start XServerXSDL and log into PRoot as the 'user' account (which we will create later)
	echo >> Start_AnBox86.sh "#!/bin/bash"
	echo >> Start_AnBox86.sh ""
	echo >> Start_AnBox86.sh "# Launch the XServer XSDL Android app from Termux. The rest of these commands will run in Termux in the background."
	echo >> Start_AnBox86.sh "am start --user 0 -n x.org.server/x.org.server.RunFromOtherApp # Launch the XServerXSDL android app"
	echo >> Start_AnBox86.sh "sleep 7s"
	echo >> Start_AnBox86.sh ""
	echo >> Start_AnBox86.sh "export PATH=$HOME/proot-static/bin:$PATH"
	echo >> Start_AnBox86.sh "export PROOT_LOADER=$HOME/proot-static/bin/loader"
	echo >> Start_AnBox86.sh ""
	echo >> Start_AnBox86.sh "# Automatically start Box86 and Wine Desktop from within the Termux user account"
	echo >> Start_AnBox86.sh "proot-distro login --bind $HOME/storage/external-1:/external-storage --bind /sdcard:/internal-storage --isolated ubuntu-arm --user user -- <<- 'EOC'" # TODO: Fix me
	echo >> Start_AnBox86.sh "	export DISPLAY=localhost:0"
	echo >> Start_AnBox86.sh "	sudo Xephyr :1 -noreset -fullscreen &"
	echo >> Start_AnBox86.sh "	DISPLAY=:1 box86 ~/wine/bin/wine explorer /desktop=wine,1280x720 explorer"
	echo >> Start_AnBox86.sh "EOC"
	#echo >> Start_AnBox86.sh "proot-distro login --bind /sdcard ubuntu-arm --user user -- DISPLAY=:1 box86 $PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu-arm/home/user/wine/bin/wine explorer /desktop=wine,1280x720 explorer"
	chmod +x Start_AnBox86.sh
	# proot-distro notes: '--bind' lets users access some Termux directories from inside PRoot: $HOME/storage/external-1 for external and in most cases, /sdcard for internal.
	#                          Note that we must bind '$HOME/storage/external-1' instead of '/storage' (since binding '/storage' results in read-only access to the external SD card and a different directory layout)
	#                     '--isolated' avoids program conflicts between Termux & PRoot (credits: Mipster)
	#                     '--user' logs into a user account
	#                     ' -- COMMANDS-HERE' lets us inject commands into the PRoot distro from Termux
	
	# Create a script to log into PRoot as the 'user' account (which we will create later)
	echo >> launch_ubuntu.sh "#!/bin/bash"
	echo >> launch_ubuntu.sh ""
	echo >> launch_ubuntu.sh "export PATH=$HOME/proot-static/bin:$PATH"
	echo >> launch_ubuntu.sh "export PROOT_LOADER=$HOME/proot-static/bin/loader"
	echo >> launch_ubuntu.sh ""
	echo >> launch_ubuntu.sh "proot-distro login --bind $HOME/storage/external-1 --bind /sdcard --isolated ubuntu-arm -- su - user"
	chmod +x launch_ubuntu.sh
	
	# Inject a 'second stage' installer script into Ubuntu
	# - This script will not be run right now.  It will be auto-run upon first login (since it is located within '/etc/profile.d/').
	run_InjectSecondStageInstaller
	
	# Log into PRoot (which will then launch the 'second stage' installer)
	echo -e "\nUbunutu PRoot guest system installed. Launching PRoot to continue the installation. . ."
	export PATH=$HOME/proot-static/bin:$PATH
	export PROOT_LOADER=$HOME/proot-static/bin/loader
	proot-distro login --isolated ubuntu-arm # Log into the Ubuntu-arm PRoot as 'root'.
	# Since we are planning to run this script from Termux using curl, when all scripts are finished, we will return to Termux.
}

# ---------------

function run_InjectSecondStageInstaller()
{
	# Inject the 'second stage' installer script into the Ubuntu-arm guest system to be run laterb (none of this gets run right now)
	cat > $PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu-arm/etc/profile.d/AnBox86b.sh <<- 'EOM'
		#!/bin/bash
		# Second stage installer script
		#  - Because this script is located within '/etc/profile.d/', bash will auto-run it upon any login into PRoot ('root' or 'user').
		echo -e "\nPRoot launch successful.  Now installing Box86 and Wine on Ubuntu PRoot. . ."
		
		# Script self-destruct (since this setup script should only be run once)
		#  - Upon first PRoot login, bash will load these commands into memory, delete this script file, then run the rest of the commands.
		rm /etc/profile.d/AnBox86b.sh
		
		apt update -y
		
		# Create a user account within PRoot & install Wine into it (best practices are to not run Wine as root).
		#  - We are currently in PRoot's 'root'.  To run commands within a 'user' account, we must push them into 'user' using heredoc.
		adduser --disabled-password --gecos "" user #BROKEN # Make a user account named 'user' without prompting us for information
		apt install sudo -y
		echo "user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers # Give the 'user' account sudo access
		#sudo su - user <<- 'EOT' #kludge - user accounts are broken at the moment
			# Install a Python3(?) dependency (a box86 compiling dependency) without prompts (prompts will freeze our 'eot' commands)
			export DEBIAN_FRONTEND=noninteractive
			ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime
			#sudo apt install tzdata -y
			apt-get install tzdata -y
			sudo dpkg-reconfigure --frontend noninteractive tzdata
			
			# Build and install Box86
			#sudo apt install git cmake python3 build-essential gcc -y # box86 dependencies
			apt-get install git cmake python3 build-essential gcc -y
			git clone https://github.com/ptitSeb/box86
			sh -c "cd box86 && cmake .. -DARM_DYNAREC=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo ~/box86 && make && make install"
			rm -rf box86 # remove box86 build directory
			
			# Install i386-Wine
			#sudo apt install wget -y
			apt-get install wget -y
			#sudo apt install libxinerama1 libfontconfig1 libxrender1 libxcomposite-dev libxi6 libxcursor-dev libxrandr2 -y # for wine on proot
			apt-get install libxinerama1 libfontconfig1 libxrender1 libxcomposite-dev libxi6 libxcursor-dev libxrandr2 -y
			wget https://twisteros.com/wine.tgz
			tar -xvzf wine.tgz
			rm wine.tgz
			
			# Give PRoot an X server ('screen 1') to send video to (and don't stop the X server after last client logs off)
			sudo apt install xserver-xephyr -y
			echo -e >> ~/.bashrc "\n# Initialize X server every time user logs in"
			echo >> ~/.bashrc "export DISPLAY=localhost:0"
			echo >> ~/.bashrc "sudo Xephyr :1 -noreset -fullscreen &"
			echo >> ~/.bashrc ""
			echo >> ~/.bashrc "# Print some instructions for the user every time they log in"
			echo >> ~/.bashrc "clear"
			echo >> ~/.bashrc "echo ''"
			echo >> ~/.bashrc "echo 'Welcome to PRoot with Box86 & Wine!'"
			echo >> ~/.bashrc "echo \" - Launch x86 programs with 'wine YourWindowsProgram.exe' or 'box86 YourLinuxProgram'.\""
			echo >> ~/.bashrc "echo \"    (don't forget to use the BOX86_NOBANNER=1 environment variable when launching winetricks)\""
			echo >> ~/.bashrc "echo ''"
			echo >> ~/.bashrc "echo \" - After launching a program, use the Android app 'XServer XSDL' to view & control it.\""
			echo >> ~/.bashrc "echo \"    (if you get display errors, make sure Android didn't put the 'XServer XSDL' app to sleep)\""
			echo >> ~/.bashrc "echo \" - The SD Card is accessable from \/sdcard\""
			
			# Make scripts and symlinks to transparently run wine with box86 (since we don't have binfmt_misc available)
			echo -e '#!/bin/bash'"\nDISPLAY=:1 setarch linux32 -L box86 $HOME/wine/bin/wine" '"$@"' | sudo tee -a /usr/local/bin/wine >/dev/null
			echo -e '#!/bin/bash'"\nbox86 $HOME/wine/bin/wineserver" '"$@"' | sudo tee -a /usr/local/bin/wineserver >/dev/null
			sudo ln -s $HOME/wine/bin/wineboot /usr/local/bin/wineboot
			sudo ln -s $HOME/wine/bin/winecfg /usr/local/bin/winecfg
			sudo chmod +x /usr/local/bin/wine /usr/local/bin/wineboot /usr/local/bin/winecfg /usr/local/bin/wineserver
			
			# Install winetricks
			#sudo apt install cabextract -y # winetricks needs this
			apt-get install cabextract -y
			wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks # download
			#sudo chmod +x winetricks
			chmod +x winetricks
			#sudo mv winetricks /usr/local/bin
			mv winetricks /usr/local/bin
			
			echo -e "\nAnBox86 installation complete."
			echo " - Start Wine Desktop with Start_AnBox86.sh."
			echo " - You can also run wine and winetricks from commandline inside PRoot. Log in with launch_ubuntu.sh"
		#EOT
		# The above commands were pushed into the 'user' account while we were in 'root'. So now that these commands are done, we will still be in 'root'.
	EOM
	# The above commands will be run in the future upon login to Ubuntu PRoot as 'root' ('user' doesn't exist yet).
}

run_Main
