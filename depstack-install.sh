#!/bin/bash

function select_menu(){
   HEIGHT=15
   WIDTH=40
   CHOICE_HEIGHT=5
   BACKTITLE="depstack"
   TITLE="安装模式"
   MENU="请选择："
    
   OPTIONS=(1 "apt版"
            2 "Docker-deepin20版"
            3 "Docker-centos7版"
            4 "k8s版"
            5 "quit退出")
    
   CHOICE=$(dialog --clear \
                   --backtitle "$BACKTITLE" \
                   --title "$TITLE" \
                   --menu "$MENU" \
                   $HEIGHT $WIDTH $CHOICE_HEIGHT \
                   "${OPTIONS[@]}" \
                   2>&1 >/dev/tty)
    
   clear
}
while [ 1 ];do
   select_menu
   case $CHOICE in
           1)
               echo "1-apt版"
               cd depStack; bash depstack-controller.sh
               ;;
           2)
               echo "2-Docker-deepin20版"
               cd depStack; bash depstack-docker-controller.sh
               ;;
           3)
               echo "3-Docker-centos7版"
               cd depStack; bash cetstack-docker-controller.sh
               ;;
           4)
               echo "4-k8s版"
               cd depStack; bash depstack-k8s.sh
               ;;
           5)
               echo "quit"
               exit 0
               ;;
           *)
               echo "no option select"
               exit 0
   esac
done
