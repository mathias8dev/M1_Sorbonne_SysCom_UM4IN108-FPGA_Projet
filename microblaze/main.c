/*******************************************************************************
 * Centrale DCC -- Code MicroBlaze
 *
 * Pilotage de l'IP Centrale DCC via bus AXI depuis le processeur MicroBlaze.
 *
 * Interface utilisateur :
 *   SW[15:12] : adresse du train (1-15, defaut 3)
 *   SW[7:0]   : selection de commande (priorite SW7 > SW6 > ... > SW0)
 *     SW7 = marche avant step 10
 *     SW6 = marche arriere step 10
 *     SW5 = phares ON (F0)
 *     SW4 = phares OFF
 *     SW3 = klaxon ON (F11)
 *     SW2 = klaxon OFF (reamorcage F11)
 *     SW1 = annonce SNCF ON (F13)
 *     SW0 = annonce SNCF OFF (F13)
 *     Aucun = arret (stop)
 *   btnR : valider et envoyer la trame a l'IP
 *   LEDs : miroir des interrupteurs bas (SW[7:0])
 *
 * Registres de l'IP Centrale DCC :
 *   Offset 0x00 (slv_reg0) : Trame_DCC(31 downto 0)
 *   Offset 0x04 (slv_reg1) : Trame_DCC(50 downto 32) dans bits [18:0]
 ******************************************************************************/

#include "xparameters.h"
#include "xgpio.h"
#include "xil_io.h"
#include "xil_printf.h"

/*---------------------------------------------------------------------------
 * Adresses de base des peripheriques
 * A adapter selon le block design genere par Vivado
 *---------------------------------------------------------------------------*/
#define GPIO_SWITCHES_BASEADDR  XPAR_AXI_GPIO_0_BASEADDR
#define GPIO_BUTTONS_BASEADDR   XPAR_AXI_GPIO_1_BASEADDR
#define GPIO_LEDS_BASEADDR      XPAR_AXI_GPIO_2_BASEADDR
#define DCC_IP_BASEADDR         XPAR_CENTRALE_DCC_V1_0_0_BASEADDR

/* Offsets des registres de l'IP DCC */
#define DCC_REG0_OFFSET  0x00   /* Trame_DCC(31:0)  */
#define DCC_REG1_OFFSET  0x04   /* Trame_DCC(50:32) */

/* Bouton de validation (btnR = bit 3 du GPIO boutons sur Basys3) */
#define BTN_RIGHT  0x08

/*---------------------------------------------------------------------------
 * Instances GPIO
 *---------------------------------------------------------------------------*/
XGpio GpioSwitches;
XGpio GpioButtons;
XGpio GpioLeds;

/*---------------------------------------------------------------------------
 * Construction d'une trame DCC 51 bits
 *
 * La trame est stockee dans un tableau de 2 x 32 bits :
 *   frame[0] = bits 31..0  (slv_reg0)
 *   frame[1] = bits 50..32 (slv_reg1, dans les bits [18:0])
 *
 * Format trame 1 octet de commande (preambule etendu a 23 bits) :
 *   [23x'1'][0][addr 8b][0][cmd 8b][0][ctrl 8b][1]  = 51 bits
 *
 * Format trame 2 octets de commande (preambule 14 bits) :
 *   [14x'1'][0][addr 8b][0][cmd1 8b][0][cmd2 8b][0][ctrl 8b][1]  = 51 bits
 *---------------------------------------------------------------------------*/

/* Construit une trame DCC 1 octet de commande */
static void build_frame_1byte(u8 addr, u8 cmd, u32 frame[2])
{
    u8 ctrl = addr ^ cmd;

    /* Construction bit a bit, MSB = bit 50 */
    /* Preambule etendu (23 bits de '1') : bits 50..28 */
    /* Start bit : bit 27 = 0 */
    /* Adresse : bits 26..19 */
    /* Start bit : bit 18 = 0 */
    /* Commande : bits 17..10 */
    /* Start bit : bit 9 = 0 */
    /* Controle : bits 8..1 */
    /* Stop bit : bit 0 = 1 */

    u64 trame = 0;

    /* Preambule : 23 bits de 1 */
    trame = 0x7FFFFFULL;           /* bits 22..0 tous a 1 = 23 bits */
    trame <<= 1;                   /* start bit = 0 */

    trame <<= 8;
    trame |= (u64)addr;           /* adresse 8 bits */

    trame <<= 1;                   /* start bit = 0 */

    trame <<= 8;
    trame |= (u64)cmd;            /* commande 8 bits */

    trame <<= 1;                   /* start bit = 0 */

    trame <<= 8;
    trame |= (u64)ctrl;           /* controle 8 bits */

    trame <<= 1;
    trame |= 1;                    /* stop bit = 1 */

    /* Separation en 2 mots de 32 bits */
    frame[0] = (u32)(trame & 0xFFFFFFFFULL);
    frame[1] = (u32)((trame >> 32) & 0x0007FFFFULL);
}

/* Construit une trame DCC 2 octets de commande */
static void build_frame_2bytes(u8 addr, u8 cmd1, u8 cmd2, u32 frame[2])
{
    u8 ctrl = addr ^ cmd1 ^ cmd2;

    u64 trame = 0;

    /* Preambule standard : 14 bits de 1 */
    trame = 0x3FFFULL;             /* bits 13..0 tous a 1 = 14 bits */
    trame <<= 1;                   /* start bit = 0 */

    trame <<= 8;
    trame |= (u64)addr;           /* adresse 8 bits */

    trame <<= 1;                   /* start bit = 0 */

    trame <<= 8;
    trame |= (u64)cmd1;           /* commande octet 1 */

    trame <<= 1;                   /* start bit = 0 */

    trame <<= 8;
    trame |= (u64)cmd2;           /* commande octet 2 */

    trame <<= 1;                   /* start bit = 0 */

    trame <<= 8;
    trame |= (u64)ctrl;           /* controle 8 bits */

    trame <<= 1;
    trame |= 1;                    /* stop bit = 1 */

    frame[0] = (u32)(trame & 0xFFFFFFFFULL);
    frame[1] = (u32)((trame >> 32) & 0x0007FFFFULL);
}

/*---------------------------------------------------------------------------
 * Envoi d'une trame a l'IP Centrale DCC
 *---------------------------------------------------------------------------*/
static void dcc_send_frame(u32 frame[2])
{
    Xil_Out32(DCC_IP_BASEADDR + DCC_REG0_OFFSET, frame[0]);
    Xil_Out32(DCC_IP_BASEADDR + DCC_REG1_OFFSET, frame[1]);
}

/*---------------------------------------------------------------------------
 * Determine la commande DCC en fonction des interrupteurs
 * et construit la trame correspondante
 *---------------------------------------------------------------------------*/
static void build_command(u8 addr, u8 switches, u32 frame[2])
{
    if (switches & 0x80) {
        /* SW7 : marche avant, vitesse step 10 */
        /* Commande vitesse : 01DXXXXX, D=1 (avant), step 10 = 10110 */
        build_frame_1byte(addr, 0x76, frame);
    }
    else if (switches & 0x40) {
        /* SW6 : marche arriere, vitesse step 10 */
        /* D=0 (arriere), step 10 = 10110 */
        build_frame_1byte(addr, 0x56, frame);
    }
    else if (switches & 0x20) {
        /* SW5 : phares ON (F0) */
        /* Commande F0-F4 : 100XXXXX, bit4=F0=1 */
        build_frame_1byte(addr, 0x90, frame);
    }
    else if (switches & 0x10) {
        /* SW4 : phares OFF */
        /* F0=0 */
        build_frame_1byte(addr, 0x80, frame);
    }
    else if (switches & 0x08) {
        /* SW3 : klaxon ON (F11) */
        /* Commande F9-F12 : 101SXXXX, S=0 (F9-F12), bit2=F11=1 */
        build_frame_1byte(addr, 0xA4, frame);
    }
    else if (switches & 0x04) {
        /* SW2 : klaxon OFF (reamorcage) */
        /* F9-F12 toutes OFF */
        build_frame_1byte(addr, 0xA0, frame);
    }
    else if (switches & 0x02) {
        /* SW1 : annonce SNCF ON (F13) */
        /* Commande F13-F20 : 11011110 + octet2 */
        build_frame_2bytes(addr, 0xDE, 0x01, frame);
    }
    else if (switches & 0x01) {
        /* SW0 : annonce SNCF OFF (reamorcage F13) */
        build_frame_2bytes(addr, 0xDE, 0x00, frame);
    }
    else {
        /* Aucun interrupteur : arret */
        /* Commande vitesse : 01DXXXXX, D=1, step=stop=00000 */
        build_frame_1byte(addr, 0x60, frame);
    }
}

/*---------------------------------------------------------------------------
 * Programme principal
 *---------------------------------------------------------------------------*/
int main(void)
{
    u32 switches;
    u32 buttons;
    u8  addr;
    u8  cmd_switches;
    u32 frame[2];
    u32 btn_prev = 0;

    xil_printf("=== Centrale DCC -- MicroBlaze ===\r\n");

    /* Initialisation des GPIO */
    XGpio_Initialize(&GpioSwitches, XPAR_AXI_GPIO_0_DEVICE_ID);
    XGpio_Initialize(&GpioButtons,  XPAR_AXI_GPIO_1_DEVICE_ID);
    XGpio_Initialize(&GpioLeds,     XPAR_AXI_GPIO_2_DEVICE_ID);

    /* Configuration des directions (1 = entree, 0 = sortie) */
    XGpio_SetDataDirection(&GpioSwitches, 1, 0xFFFF);  /* 16 entrees */
    XGpio_SetDataDirection(&GpioButtons,  1, 0x1F);    /* 5 entrees  */
    XGpio_SetDataDirection(&GpioLeds,     1, 0x0000);  /* 16 sorties */

    /* Trame initiale : arret du train adresse 3 */
    build_frame_1byte(3, 0x60, frame);
    dcc_send_frame(frame);
    xil_printf("Trame initiale envoyee (arret train 3)\r\n");

    /* Boucle principale (polling) */
    while (1) {
        /* Lecture des peripheriques */
        switches = XGpio_DiscreteRead(&GpioSwitches, 1);
        buttons  = XGpio_DiscreteRead(&GpioButtons,  1);

        /* Extraction de l'adresse (SW[15:12]), defaut 3 si 0 */
        addr = (u8)((switches >> 12) & 0x0F);
        if (addr == 0) addr = 3;

        /* Extraction des commandes (SW[7:0]) */
        cmd_switches = (u8)(switches & 0xFF);

        /* Affichage sur les LEDs : commande en cours sur LED[7:0] */
        XGpio_DiscreteWrite(&GpioLeds, 1, (u32)cmd_switches);

        /* Detection du front montant de btnR (validation) */
        if ((buttons & BTN_RIGHT) && !(btn_prev & BTN_RIGHT)) {
            /* Construction et envoi de la trame */
            build_command(addr, cmd_switches, frame);
            dcc_send_frame(frame);

            xil_printf("Trame envoyee: addr=%d, SW=0x%02X\r\n",
                        addr, cmd_switches);
        }

        btn_prev = buttons;
    }

    return 0;
}
