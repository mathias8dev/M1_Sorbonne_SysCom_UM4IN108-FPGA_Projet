# Centrale DCC sur FPGA -- Rapport de projet

**UE MU4IN108 -- Systemes Programmables -- M1 SESI, Sorbonne Universite**

---

## 1. Presentation du projet

Le projet consiste a implementer une **Centrale DCC** (Digital Command Control) sur la carte FPGA Basys 3 (Artix-7, xc7a35tcpg236-1). Le protocole DCC est le standard de commande individuelle des locomotives en modelisme ferroviaire : les commandes sont modulees directement sur la tension d'alimentation des rails.

Le systeme produit en sortie un signal numerique DCC qui, apres amplification par un Booster externe, pilote les decodeurs embarques dans les locomotives. L'utilisateur selectionne la commande souhaitee via les 8 interrupteurs de la carte ; le bouton central sert de Reset.

### Objectifs

1. Decrire en VHDL les modules manquants de l'architecture.
2. Verifier chaque module par un testbench comportemental avec des ASSERT.
3. Assembler le systeme complet dans un module Top et valider par simulation.
4. Implementer sur la carte et verifier le signal DCC a l'oscilloscope.

---

## 2. Le protocole DCC en bref

### 2.1 Codage des bits

Un bit DCC est une impulsion bipolaire : phase basse puis phase haute, d'egales durees.

| Bit | Duree de chaque demi-periode |
|-----|------------------------------|
| 1   | 58 us                        |
| 0   | 100 us                       |

La tolerance admise est de **+/- 3 us** par demi-periode.

### 2.2 Structure d'une trame

```
[Preambule >= 14 x '1'] [0] [Adresse 8b] [0] [Commande 8-16b] [0] [Controle 8b] [1]
                         ^start              ^start              ^start            ^stop
```

- **Preambule** : au moins 14 bits a 1 (synchronisation).
- **Start bits** : bits a 0 separant chaque champ.
- **Champ de controle** : XOR de tous les octets precedents (detection d'erreur).
- **Stop bit** : un bit a 1 terminant la trame.
- Les trames sont emises en continu, separees par un **intervalle de 6 ms**.

### 2.3 Commandes utilisees

| Commande         | Format du champ commande              | Octets |
|------------------|---------------------------------------|--------|
| Vitesse/Direction| `01DXXXXX` (D = direction, X = speed) | 1      |
| Fonctions F0-F4  | `100XXXXX`                            | 1      |
| Fonctions F5-F12 | `101SXXXX` (S selectionne le groupe)  | 1      |
| Fonctions F13-F20| `11011110` + `XXXXXXXX`               | 2      |

---

## 3. Architecture du systeme

L'architecture suit fidelement le schema de la Figure 3 du sujet. Tous les modules sont cadences par l'horloge 100 MHz de la carte ; une horloge derivee a 1 MHz sert de base de temps pour le protocole DCC.

```
                          CLK 100MHz   RESET
                             |           |
                   +---------+-----------+----------+
                   |                                |
            +------v------+                  +------v------+
            | CLK_DIV     |                  | GENERATEUR  |
            | 100M -> 1M  |                  | TRAMES TEST |
            +------+------+                  +------+------+
                   |                                |
              CLK_1MHz                         TRAME_DCC (51 bits)
                   |                                |
          +--------+--------+                +------v------+
          |        |        |                | REGISTRE    |
          v        v        v                | DCC (51b)   |<--- COM_REG
     +----+--+ +---+---+ +-+------+         +------+------+
     |COMPTEUR| |DCC    | |DCC    |                |
     |TEMPO   | |BIT_1  | |BIT_0  |           Bit_Courant
     |6 ms    | |58us   | |100us  |                |
     +---+----+ +---+---+ +---+---+         +------v------+
         |          |          |             |    MAE      |
    Fin_Tempo    Fin_1      Fin_0            | (9 etats)   |
         |          |          |             +--+--+--+--+-+
         +----------+----------+-------------+  |  |  |  |
                                    Go_1 Go_0 Start COM_REG
                                                Tempo

     Sortie_DCC = DCC_1 OR DCC_0
```

### Justification de l'architecture modulaire

Chaque fonction (comptage, generation de bit, sequencement) est isolee dans un module dedie. Cette decomposition apporte trois avantages :

1. **Testabilite** : chaque module peut etre verifie independamment avec son propre testbench, ce qui facilite la localisation des erreurs.
2. **Reutilisabilite** : les modules DCC_BIT_1 et DCC_BIT_0 partagent strictement la meme structure ; seule la valeur de seuil du compteur differe.
3. **Lisibilite** : le module Top_DCC se reduit a une pure interconnexion de composants (architecture structurelle), sans logique supplementaire hormis la porte OU finale.

---

## 4. Description des modules implementes

### 4.1 DCC_BIT_1 -- Generateur de bit DCC a 1

**Fichier** : `src/DCC_Bit_1.vhd`

#### Interface

| Port    | Direction | Largeur | Role                           |
|---------|-----------|---------|--------------------------------|
| Clk     | in        | 1       | Horloge 100 MHz (FSM)          |
| Clk1M   | in        | 1       | Horloge 1 MHz (compteur)       |
| Reset   | in        | 1       | Reset asynchrone               |
| Go      | in        | 1       | Ordre de generation (MAE)      |
| Fin     | out       | 1       | Fin de transmission             |
| DCC_Out | out       | 1       | Signal de sortie DCC            |

#### Architecture interne

Le module se compose de **deux processus** operant dans deux domaines d'horloge differents, comme impose par le sujet :

- **FSM a 100 MHz** (5 etats) : orchestre les phases de generation.
- **Compteur a 1 MHz** : mesure les durees des demi-periodes avec une resolution de 1 us.

#### Machine a etats (5 etats)

```
IDLE ---[Go='1']--> LOW_PHASE ---[Cpt=57]--> RESET_CTR ---[Cpt=0]--> HIGH_PHASE ---[Cpt=57]--> DONE ---[Go='0']--> IDLE
```

| Etat       | DCC_Out | Fin | Raz_Cpt | Inc_Cpt | Description                                    |
|------------|---------|-----|---------|---------|------------------------------------------------|
| IDLE       | 0       | 0   | 1       | 0       | Repos, compteur maintenu a zero                |
| LOW_PHASE  | 0       | 0   | 0       | 1       | Phase basse, compteur actif                    |
| RESET_CTR  | 1       | 0   | 1       | 0       | Remise a zero du compteur entre les deux phases|
| HIGH_PHASE | 1       | 0   | 0       | 1       | Phase haute, compteur actif                    |
| DONE       | 0       | 1   | 1       | 0       | Transmission terminee, attente relachement Go  |

#### Justification de l'etat RESET_CTR

Le compteur est cadence a 1 MHz tandis que la FSM evolue a 100 MHz. Quand la FSM detecte `Fin_Cpt='1'` (compteur = 57) a la fin de la phase basse, elle doit reinitialiser le compteur avant de compter la phase haute. Or un signal de reset emis pendant un seul cycle a 100 MHz (10 ns) pourrait ne pas etre echantillonne par le front montant a 1 MHz suivant.

L'etat **RESET_CTR** resout ce probleme : la FSM y **maintient** `Raz_Cpt='1'` jusqu'a ce que `Fin_Cpt` repasse a `'0'`, confirmant que le compteur a bien ete reinitialise. Cette attente dure au maximum 1 us (une periode de CLK_1MHz), soit bien en deca de la tolerance de 3 us du protocole DCC.

Pendant RESET_CTR, `DCC_Out` est deja positionne a `'1'`, de sorte que la transition du signal de sortie se fait sans delai visible par le decodeur DCC.

#### Seuil du compteur

Le compteur compte de 0 a 57, soit **58 ticks a 1 MHz = 58 us** par demi-periode, conformement a la specification du bit DCC a 1.

### 4.2 DCC_BIT_0 -- Generateur de bit DCC a 0

**Fichier** : `src/DCC_Bit_0.vhd`

Structure identique a DCC_BIT_1. La seule difference est le seuil du compteur : **99** au lieu de 57, ce qui produit des demi-periodes de **100 us** (100 ticks a 1 MHz).

Ce partage de structure entre les deux modules est volontaire : il minimise l'effort de verification (un seul testbench couvre les deux architectures en variant uniquement les durees attendues) et garantit un comportement symetrique.

### 4.3 REGISTRE_DCC -- Registre a decalage 51 bits

**Fichier** : `src/Registre_DCC.vhd`

#### Interface

| Port        | Direction | Largeur | Role                                     |
|-------------|-----------|---------|------------------------------------------|
| Clk         | in        | 1       | Horloge 100 MHz                          |
| Reset       | in        | 1       | Reset asynchrone                         |
| COM_REG     | in        | 2       | Commande : "01" = load, "10" = shift     |
| Trame_DCC   | in        | 51      | Trame a charger en parallele             |
| Bit_Courant | out       | 1       | MSB du registre (bit en cours d'emission)|

#### Fonctionnement

```
COM_REG = "01" : Reg <= Trame_DCC          (chargement parallele)
COM_REG = "10" : Reg <= Reg(49..0) & '0'   (decalage gauche, MSB sort)
COM_REG = "00" : Reg inchange               (maintien)
```

#### Justification de la largeur 51 bits

La trame DCC la plus longue contient :
- Preambule : 14 bits
- Start + Adresse + Start + Commande octet 1 + Start + Commande octet 2 + Start + Controle + Stop : 14 + 1 + 8 + 1 + 8 + 1 + 8 + 1 + 8 + 1 = 37 bits

Total = 14 + 37 = **51 bits**.

Pour les trames a un seul octet de commande (42 bits utiles), le preambule est **etendu a 23 bits** de `'1'` pour remplir les 51 bits. Cela est parfaitement conforme au protocole DCC qui impose un preambule d'*au moins* 14 bits. L'avantage majeur : **la MAE traite toujours exactement 51 bits**, sans logique de gestion de longueur variable.

#### Valeur de reset

Au reset, le registre est initialise a tout `'1'`. Ainsi, si la MAE commence a transmettre avant le premier chargement, elle n'emet que des bits '1', ce qui est interprete comme un preambule (inoffensif) par les decodeurs DCC.

### 4.4 MAE -- Machine a Etats principale

**Fichier** : `src/MAE.vhd`

#### Interface

| Port        | Direction | Largeur | Role                             |
|-------------|-----------|---------|----------------------------------|
| Clk         | in        | 1       | Horloge 100 MHz                  |
| Reset       | in        | 1       | Reset asynchrone                 |
| Bit_Courant | in        | 1       | MSB du registre                  |
| Fin_1       | in        | 1       | Fin de DCC_BIT_1                 |
| Fin_0       | in        | 1       | Fin de DCC_BIT_0                 |
| Fin_Tempo   | in        | 1       | Fin de temporisation             |
| Go_1        | out       | 1       | Active DCC_BIT_1                 |
| Go_0        | out       | 1       | Active DCC_BIT_0                 |
| Start_Tempo | out       | 1       | Demarre la temporisation         |
| COM_REG     | out       | 2       | Commande du registre             |

#### Machine a etats (9 etats)

```
           +------+
  RESET -->| LOAD |  COM_REG = "01" (chargement), Bit_Count = 0
           +--+---+
              |
              v
           +------+
     +---->| SEND |  Lit Bit_Courant
     |     +--+---+
     |        |
     |   Bit='1'  Bit='0'
     |     |         |
     |     v         v
     |  +------+  +------+
     |  |SEND_1|  |SEND_0|  Go_1='1' / Go_0='1'
     |  +--+---+  +--+---+
     |     |         |
     |     v         v
     |  +------+  +------+
     |  |WAIT_1|  |WAIT_0|  Attend Fin_1='1' / Fin_0='1'
     |  +--+---+  +--+---+
     |     |         |
     |     +----+----+
     |          |
     |          v
     |     +-------+
     |     | SHIFT |  COM_REG = "10", Bit_Count++
     |     +---+---+
     |         |
     |   Bit_Count<50    Bit_Count=50
     |     |                   |
     +-----+                   v
                         +-----------+
                         |START_TEMP |  Start_Tempo = '1'
                         +-----+-----+
                               |
                               v
                         +-----------+
                         |WAIT_TEMP  |  Attend Fin_Tempo = '1'
                         +-----+-----+
                               |
                               v
                            [LOAD]  (boucle)
```

#### Justification des choix de conception

**Separation SEND / SEND_x / WAIT_x** : L'etat SEND lit `Bit_Courant` et branche vers SEND_1 ou SEND_0. Les etats SEND_x activent le signal `Go` correspondant (Go_1 ou Go_0), puis WAIT_x maintient Go actif jusqu'a reception de Fin. Cette separation en 3 etats (lecture / activation / attente) garantit que :

1. Le bit est lu **apres** le decalage du registre (SEND est atteint un cycle apres SHIFT, laissant le temps au registre de presenter le nouveau MSB).
2. Le signal Go est actif pendant **toute la duree** de generation du bit DCC, conformement au protocole de handshake impose par les modules DCC_BIT.
3. Go repasse a `'0'` des la transition vers SHIFT, ce qui permet au module DCC_BIT de revenir a l'etat IDLE.

**Compteur de bits** : Le compteur `Bit_Count` s'incremente dans l'etat SHIFT. Quand il atteint 50 (51eme bit transmis), la MAE passe a la temporisation plutot que de revenir a SEND. Cela evite toute comparaison signee ou gestion de debordement.

**Sorties combinatoires** : Toutes les sorties de la MAE sont des equations combinatoires de l'etat courant (style Moore). Ce choix evite les glitchs qui pourraient survenir avec des sorties de type Mealy, et simplifie la verification temporelle.

### 4.5 DCC_FRAME_GENERATOR -- Generateur de trames de test

**Fichier** : `src/Generateur_Trames.vhd`

Module purement combinatoire qui genere une trame DCC de 51 bits en fonction de la position des interrupteurs. L'adresse du train cible est fixee a **3** (`00000011`).

#### Table des trames

| Switch | Commande                       | Octet commande | Octet controle (XOR) |
|--------|--------------------------------|----------------|----------------------|
| SW7    | Marche avant, vitesse step 10  | `01110110`     | `01110101`           |
| SW6    | Marche arriere, vitesse step 10| `01010110`     | `01010101`           |
| SW5    | Phares ON (F0)                 | `10010000`     | `10010011`           |
| SW4    | Phares OFF                     | `10000000`     | `10000011`           |
| SW3    | Klaxon ON (F11)                | `10100100`     | `10100111`           |
| SW2    | Klaxon OFF (reamorcage F11)    | `10100000`     | `10100011`           |
| SW1    | Annonce SNCF ON (F13)          | `11011110` + `00000001` | `11011100`  |
| SW0    | Annonce SNCF OFF (F13)         | `11011110` + `00000000` | `11011101`  |
| Aucun  | Arret (stop)                   | `01100000`     | `01100011`           |

#### Justification du calcul des champs de controle

Chaque octet de controle est le XOR de tous les octets de donnees de la trame. Exemple pour SW7 (marche avant) :

```
  Adresse :   00000011
  Commande:   01110110
  -----------------------
  XOR     :   01110101   (controle)
```

Verification : `0x03 XOR 0x76 = 0x75` = `01110101`. Correct.

Pour les commandes a 2 octets (SW1/SW0, fonctions F13-F20) :

```
  Adresse :   00000011
  Cmd octet1: 11011110
  Cmd octet2: 00000001   (F13 ON)
  --------------------------
  XOR     :   11011100   (controle)
```

Verification : `0x03 XOR 0xDE XOR 0x01 = 0xDC` = `11011100`. Correct.

#### Priorite des interrupteurs

Le processus utilise une structure `if/elsif` : si plusieurs interrupteurs sont actifs simultanement, celui de **poids fort** (SW7) est prioritaire. Ce comportement est conforme au squelette fourni.

#### Preambule etendu pour les trames a 1 octet

Les trames a un octet de commande n'occupent que 42 bits. Pour remplir les 51 bits du registre, le preambule est etendu a **23 bits** (au lieu de 14). Le standard DCC imposant un minimum de 14 bits de preambule, toute valeur superieure est valide. Les trames a 2 octets (SW1, SW0) utilisent les 14 bits standard de preambule, car elles occupent naturellement les 51 bits.

### 4.6 TOP_DCC -- Module top-level

**Fichier** : `src/Top_DCC.vhd`

Architecture purement **structurelle** : le module Top_DCC ne contient aucune logique propre. Il se limite a :

1. **Instancier** les 7 composants (CLK_DIV, COMPTEUR_TEMPO, DCC_FRAME_GENERATOR, REGISTRE_DCC, MAE, DCC_BIT_1, DCC_BIT_0).
2. **Interconnecter** les signaux conformement au schema d'architecture.
3. Realiser la **porte OU** finale : `Sortie_DCC <= DCC_1 or DCC_0`.

La porte OU est justifiee par le fait qu'a tout instant, **un seul** des deux modules DCC_BIT est actif (l'autre a sa sortie a `'0'` en IDLE). Le OU logique combine donc sans conflit les deux signaux.

### 4.7 Contraintes (XDC)

**Fichier** : `constraints/Top_DCC.xdc`

| Signal       | Broche | Peripherique Basys 3          |
|--------------|--------|-------------------------------|
| Clk_100MHz   | W5     | Oscillateur embarque          |
| Reset        | U18    | Bouton central (btnC)         |
| Interrupteur | V17-W13| Interrupteurs SW0 a SW7       |
| Sortie_DCC   | A15    | PMOD B, broche 4 (JB[4])     |

La sortie DCC est placee sur **JB[4]** conformement aux specifications du sujet, pour etre connectee au Booster externe.

---

## 5. Interaction entre les domaines d'horloge

Le systeme utilise deux horloges : 100 MHz (systeme) et 1 MHz (base de temps DCC). Puisque CLK_1MHz est generee par le diviseur CLK_DIV a partir de CLK_100MHz, les deux horloges sont **synchrones** (la 1 MHz est un sous-multiple exact de la 100 MHz). Il n'y a donc pas de risque de metastabilite.

Neanmoins, les signaux de commande du compteur (`Raz_Cpt`, `Inc_Cpt`) produits par la FSM a 100 MHz doivent etre stables pendant au moins une periode de 1 MHz (1 us) pour etre correctement echantillonnes. Deux mecanismes garantissent cela :

1. En **IDLE** et **DONE**, `Raz_Cpt='1'` est maintenu de maniere continue (etats stables).
2. L'etat **RESET_CTR** maintient `Raz_Cpt='1'` tant que le compteur n'est pas effectivement a zero (`Fin_Cpt='0'`), assurant une duree minimale de 1 us.

---

## 6. Strategie de verification (testbenches)

Chaque module dispose d'un testbench dedie dans le repertoire `sim/`. La philosophie de test suit une approche **ascendante** : les modules elementaires sont valides en premier, puis le systeme complet.

### 6.1 TB_DCC_BIT_1 / TB_DCC_BIT_0

**Objectif** : Verifier que les timings DCC respectent la tolerance de +/- 3 us.

**Methode** :
1. Appliquer un Reset, verifier les sorties initiales (`DCC_Out=0`, `Fin=0`).
2. Activer `Go`, mesurer la duree de la phase basse (temps entre l'activation et le front montant de `DCC_Out`).
3. Mesurer la duree de la phase haute (temps entre le front montant et `Fin='1'`).
4. Verifier que chaque duree est dans l'intervalle `[55 us, 61 us]` (bit 1) ou `[97 us, 103 us]` (bit 0).
5. Verifier le handshake : `Fin` reste a `'1'` tant que `Go='1'` ; `Fin` repasse a `'0'` quand `Go='0'`.
6. Generer un second bit pour confirmer le fonctionnement repetitif.

**ASSERT utilises** :
- Verification des sorties apres reset.
- Verification des durees avec tolerance.
- Verification du protocole de handshake Go/Fin.

### 6.2 TB_REGISTRE_DCC

**Objectif** : Verifier les trois operations (load, shift, hold) et la coherence du MSB.

**Methode** :
1. Charger une trame alternee (`101010...`) et verifier que `Bit_Courant` correspond au MSB.
2. Effectuer des decalages et verifier l'alternance 1/0 du MSB.
3. Verifier que le mode maintien (`COM_REG="00"`) ne modifie pas le contenu.
4. Charger une trame DCC reelle (arret train 3) et verifier que les 23 premiers decalages produisent un bit '1' (preambule), puis un '0' (start bit).

### 6.3 TB_MAE

**Objectif** : Verifier le sequencement complet de la MAE sans les delais reels des modules DCC_BIT.

**Methode** : Les signaux `Fin_1`, `Fin_0` et `Fin_Tempo` sont generes manuellement par le testbench pour simuler les reponses des modules DCC_BIT et COMPTEUR_TEMPO. Cela permet de verifier la MAE en quelques microsecondes de simulation au lieu de plusieurs millisecondes.

1. Verifier `COM_REG="01"` (load) apres reset.
2. Simuler l'envoi d'un bit '1' : verifier `Go_1='1'`, puis fournir `Fin_1='1'`.
3. Simuler l'envoi d'un bit '0' : verifier `Go_0='1'`, puis fournir `Fin_0='1'`.
4. Repeter pour 51 bits, verifier que la MAE passe en temporisation.
5. Fournir `Fin_Tempo='1'`, verifier le retour a LOAD.

### 6.4 TB_TOP_DCC

**Objectif** : Test d'integration du systeme complet avec les horloges reelles.

**Methode** :
1. Appliquer le Reset, verifier la sortie a `'0'`.
2. Attendre le premier front montant de `Sortie_DCC` (debut de la trame).
3. Mesurer un bit '1' du preambule et verifier le timing.
4. Laisser le systeme tourner 20 ms (temps d'une trame complete + tempo).
5. Changer la commande (SW7 = marche avant) et verifier que le systeme continue a generer un signal DCC actif.

**Note** : La simulation du Top complet prend environ 40 ms de temps simule. Avec un pas de 10 ns, cela represente 4 millions de cycles. Il est recommande de verifier visuellement les chronogrammes dans le viewer de Vivado en complement des ASSERT automatiques.

---

## 7. Arborescence du projet

```
M1_Sorbonne_SysCom_UM4IN108-FPGA_Projet/
|
|-- Codes source a recuperer-20260220/    (fichiers fournis)
|   |-- Diviseur_Horloge.vhd             CLK_DIV : 100 MHz -> 1 MHz
|   |-- Compteur_Tempo.vhd               COMPTEUR_TEMPO : temporisation 6 ms
|   |-- Generateur_Trames.vhd            Squelette original (non complete)
|   +-- Basys-3-Master.xdc               Contraintes generiques Basys 3
|
|-- src/                                  (modules implementes)
|   |-- DCC_Bit_1.vhd                    Generateur de bit DCC '1'
|   |-- DCC_Bit_0.vhd                    Generateur de bit DCC '0'
|   |-- Registre_DCC.vhd                 Registre a decalage 51 bits
|   |-- MAE.vhd                          Machine a etats principale
|   |-- Generateur_Trames.vhd            Trames de test completees (train 3)
|   +-- Top_DCC.vhd                      Module top-level
|
|-- sim/                                  (testbenches)
|   |-- TB_DCC_Bit_1.vhd
|   |-- TB_DCC_Bit_0.vhd
|   |-- TB_Registre_DCC.vhd
|   |-- TB_MAE.vhd
|   +-- TB_Top_DCC.vhd
|
|-- constraints/
|   +-- Top_DCC.xdc                      Contraintes pour le Top_DCC
|
+-- RAPPORT.md                           Ce document
```

---

## 8. Guide d'utilisation dans Vivado

### 8.1 Creation du projet

1. Ouvrir Vivado, creer un nouveau projet RTL pour la cible **xc7a35tcpg236-1** (Basys 3).
2. Ajouter comme **Design Sources** :
   - `Codes source a recuperer-20260220/Diviseur_Horloge.vhd`
   - `Codes source a recuperer-20260220/Compteur_Tempo.vhd`
   - Tous les fichiers de `src/`
3. Ajouter comme **Simulation Sources** : tous les fichiers de `sim/`
4. Ajouter comme **Constraints** : `constraints/Top_DCC.xdc`
5. Definir `TOP_DCC` comme module top.

### 8.2 Simulation

- Selectionner le testbench souhaite (ex: `TB_DCC_BIT_1`) comme top de simulation.
- Lancer la simulation comportementale.
- Verifier l'absence de messages `ERREUR` dans la console.
- Pour TB_TOP_DCC, simuler au moins 40 ms et examiner les chronogrammes.

### 8.3 Synthese et implementation

- Lancer Run Synthesis, verifier l'absence de Critical Warnings.
- Lancer Run Implementation, puis Generate Bitstream.
- Programmer la carte et verifier le signal sur JB[4] a l'oscilloscope.

### 8.4 Utilisation sur la carte

| Interrupteur | Effet                                     |
|--------------|-------------------------------------------|
| Aucun        | Train a l'arret                           |
| SW7          | Marche avant (vitesse step 10)            |
| SW6          | Marche arriere (vitesse step 10)          |
| SW5          | Allumage des phares                       |
| SW4          | Extinction des phares                     |
| SW3          | Klaxon (F11 ON)                           |
| SW2          | Reamorcage klaxon (F11 OFF)               |
| SW1          | Annonce SNCF (F13 ON)                     |
| SW0          | Reamorcage annonce (F13 OFF)              |
| Bouton C     | Reset du systeme                          |

Pour le klaxon et l'annonce, activer puis desactiver la fonction entre chaque utilisation (SW3 puis SW2 pour deux coups de klaxon).

---

## 9. Bilan et perspectives

Le systeme implemente couvre l'integralite de la Partie 4 du sujet : generation de trames DCC conformes au protocole, emission continue avec temporisation de 6 ms, et commande via les interrupteurs de la carte Basys 3.

Les choix de conception (registre fixe a 51 bits, preambule etendu, FSM Moore, etat RESET_CTR pour la synchronisation inter-horloges) privilegient la **simplicite** et la **robustesse** tout en respectant strictement les specifications du protocole DCC et les tolerances de timing imposees.

Pour la suite du projet (Partie III du sujet), le module `DCC_FRAME_GENERATOR` sera remplace par un **AXI Wrapper** permettant au Microblaze de piloter la Centrale DCC via le bus AXI. Les autres modules (MAE, DCC_BIT, REGISTRE_DCC, CLK_DIV, COMPTEUR_TEMPO) restent inchanges et constituent le coeur de l'IP.
