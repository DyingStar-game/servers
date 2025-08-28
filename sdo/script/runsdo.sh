# update mariadb host
git clone https://github.com/DyingStar-game/SDO.git /var/www/html/
cd /var/www/html/
/usr/local/bin/composer install
sed -i -e 's/localhost/mariadb/g' phinx.php
sed -i -e 's/127.0.0.1/mqtt-sdo/g' src/Controllers/Mqtt.php

./vendor/bin/phinx migrate
echo "start php scripts in background"
cd /var/www/html/runTopics && php SubPlayersChanges.php &
cd /var/www/html/runTopics && php SubRegister.php &
cd /var/www/html/runTopics && php SubServerFree.php &
cd /var/www/html/runTopics && php SubServerTooHeavy.php &
echo "finished start scripts, let's gooooo"
tail -f /dev/null