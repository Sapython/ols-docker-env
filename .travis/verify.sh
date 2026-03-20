#!/bin/bash

set -o errexit
EX_DM='example.com' 
LSWS_HOST="${LSWS_HOST:-litespeed}"
LSWS_HTTP_PORT="${LSWS_HTTP_PORT:-80}"
LSWS_HTTPS_PORT="${LSWS_HTTPS_PORT:-443}"
LSWS_ADMIN_PORT="${LSWS_ADMIN_PORT:-7080}"
PHPMYADMIN_HOST="${PHPMYADMIN_HOST:-phpmyadmin}"
PHPMYADMIN_PORT="${PHPMYADMIN_PORT:-80}"

install_demo(){
    ./bin/demosite.sh
}

verify_lsws(){
    docker compose exec -T litespeed curl -sIk "http://${LSWS_HOST}:${LSWS_ADMIN_PORT}/" | grep -i LiteSpeed
    if [ ${?} = 0 ]; then
        echo "[O]  http://${LSWS_HOST}:${LSWS_ADMIN_PORT}/"
    else
        echo "[X]  http://${LSWS_HOST}:${LSWS_ADMIN_PORT}/"
        exit 1
    fi          
}    

verify_page(){
    docker compose exec -T litespeed curl -sIk "http://${LSWS_HOST}:${LSWS_HTTP_PORT}/" | grep -i WordPress
    if [ ${?} = 0 ]; then
        echo "[O]  http://${LSWS_HOST}:${LSWS_HTTP_PORT}/" 
    else
        echo "[X]  http://${LSWS_HOST}:${LSWS_HTTP_PORT}/"
        docker compose exec -T litespeed curl -sIk "http://${LSWS_HOST}:${LSWS_HTTP_PORT}/"
        exit 1
    fi        
    docker compose exec -T litespeed curl -sIk "https://${LSWS_HOST}:${LSWS_HTTPS_PORT}/" | grep -i WordPress
    if [ ${?} = 0 ]; then
        echo "[O]  https://${LSWS_HOST}:${LSWS_HTTPS_PORT}/" 
    else
        echo "[X]  https://${LSWS_HOST}:${LSWS_HTTPS_PORT}/"
        docker compose exec -T litespeed curl -sIk "https://${LSWS_HOST}:${LSWS_HTTPS_PORT}/"
        exit 1
    fi       
}

verify_phpadmin(){
    docker compose exec -T litespeed curl -sIk "http://${PHPMYADMIN_HOST}:${PHPMYADMIN_PORT}/" | grep -i phpMyAdmin
    if [ ${?} = 0 ]; then
        echo "[O]  http://${PHPMYADMIN_HOST}:${PHPMYADMIN_PORT}/" 
    else
        echo "[X]  http://${PHPMYADMIN_HOST}:${PHPMYADMIN_PORT}/"
        exit 1
    fi     
}

verify_add_vh_wp(){
    echo "Setup a WordPress site with ${EX_DM} domain"
    bash bin/domain.sh --add "${EX_DM}"
    bash bin/database.sh --domain "${EX_DM}"
    bash bin/appinstall.sh --app wordpress --domain "${EX_DM}"
    docker compose exec -T litespeed curl -sIk "http://${LSWS_HOST}:${LSWS_HTTP_PORT}/" -H "Host: ${EX_DM}" | grep -i WordPress
    if [ ${?} = 0 ]; then
        echo "[O]  http://${EX_DM}:${LSWS_HTTP_PORT}/"
    else
        echo "[X]  http://${EX_DM}:${LSWS_HTTP_PORT}/"
        docker compose exec -T litespeed curl -sIk "http://${LSWS_HOST}:${LSWS_HTTP_PORT}/" -H "Host: ${EX_DM}"
        exit 1
    fi
}
verify_del_vh_wp(){
    echo "Remove ${EX_DM} domain"
    bash bin/domain.sh --del ${EX_DM}
    if [ ${?} = 0 ]; then
        echo "[O]  ${EX_DM} VH is removed"
    else
        echo "[X]  ${EX_DM} VH is not removed"
        exit 1
    fi
    echo "Remove examplecom DataBase"
    bash bin/database.sh --delete -DB examplecom
}

verify_owasp(){
    echo 'Updating LSWS'
    bash bin/webadmin.sh --upgrade 2>&1 /dev/null
    echo 'Enabling OWASP'
    bash bin/webadmin.sh --mod-secure enable
    docker compose exec -T litespeed curl -sIk "http://${LSWS_HOST}:${LSWS_HTTP_PORT}/phpinfo.php" | awk '/HTTP/ && /403/'
    if [ ${?} = 0 ]; then
        echo '[O]  OWASP enable' 
    else
        echo '[X]  OWASP enable'
        docker compose exec -T litespeed curl -sIk "http://${LSWS_HOST}:${LSWS_HTTP_PORT}/phpinfo.php" | awk '/HTTP/ && /403/'
        exit 1
    fi
    bash bin/webadmin.sh --mod-secure disable
    docker compose exec -T litespeed curl -sIk "http://${LSWS_HOST}:${LSWS_HTTP_PORT}/phpinfo.php" | grep -i WordPress
    if [ ${?} = 0 ]; then
        echo '[O]  OWASP disable' 
    else
        echo '[X]  OWASP disable'
        docker compose exec -T litespeed curl -sIk "http://${LSWS_HOST}:${LSWS_HTTP_PORT}/phpinfo.php"
        exit 1
    fi       
}


main(){
    verify_lsws
    verify_phpadmin
    install_demo
    verify_page
    verify_owasp
    verify_add_vh_wp
    verify_del_vh_wp
}
main