#!/bin/bash
mkdir ~/.ssh/
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0ol7jQ4umQMrE1qtXnyeYk/23g6zVJyVPh0+rljElu/7zj6iJZtixxs+LebPH6mZP13RIGPP0GlrSXRVBj9F2pjb/Y/PMyHBq3+BMeiYhn6XmNMwtTK2O69vvFZQi0M3wTVSezP9OxxrPay+eCXkGVi8lnh6ZDMrvSKI2c5SQ7wFJfT/4XTxzcP2gsotRV0rzADie1EF4MYke+ZJuiwnrFbZpeogrNtSvivR4f/g0/fD8NOjCKgbk4uY//6YhEqNaGhm0wABKt0MtimmxLLe2kosoFS539t88y5tD4ispcxlOAtVKZEL1ogf0VRrcBWSTfIiJty5vw6aRTfoFwuzZ ootsuka@fraction.jp" > ~/.ssh/id_rsa.pub
source ~/devstack/openrc demo demo
nova keypair-add --pub-key ~/.ssh/id_rsa.pub default
