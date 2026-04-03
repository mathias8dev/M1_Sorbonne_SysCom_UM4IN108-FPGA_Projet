/*******************************************************************************
 * Centrale DCC -- Code MicroBlaze avec commande UART
 *
 * Pilotage de l'IP Centrale DCC via bus AXI depuis le processeur MicroBlaze.
 * Accepte des commandes depuis le port serie (UART) en plus des interrupteurs.
 *
 * Protocole serie (ligne terminee par \n) :
 *   CMD:FWD:<addr>:<step>   Marche avant, vitesse step 1-28
 *   CMD:REV:<addr>:<step>   Marche arriere, vitesse step 1-28
 *   CMD:STOP:<addr>         Arret
 *   CMD:F0ON:<addr>         Phares ON
 *   CMD:F0OFF:<addr>        Phares OFF
 *   CMD:F11ON:<addr>        Klaxon ON
 *   CMD:F11OFF:<addr>       Klaxon OFF
 *   CMD:F13ON:<addr>        Annonce SNCF ON
 *   CMD:F13OFF:<addr>       Annonce SNCF OFF
 *   CMD:PING                Test de connexion
 *
 * Reponses :
 *   OK:<echo>               Commande executee
 *   ERR:<message>           Erreur
 *   PONG                    Reponse au ping
 *
 * Registres de l'IP Centrale DCC :
 *   Offset 0x00 (slv_reg0) : Trame_DCC(31 downto 0)
 *   Offset 0x04 (slv_reg1) : Trame_DCC(50 downto 32) dans bits [18:0]
 ******************************************************************************/

#include "xparameters.h"
#include "xgpio.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xuartlite.h"

/*---------------------------------------------------------------------------
 * Adresses de base des peripheriques
 * A adapter selon le block design genere par Vivado
 *---------------------------------------------------------------------------*/
#define GPIO_SWITCHES_BASEADDR  XPAR_AXI_GPIO_0_BASEADDR
#define GPIO_BUTTONS_BASEADDR   XPAR_AXI_GPIO_1_BASEADDR
#define GPIO_LEDS_BASEADDR      XPAR_AXI_GPIO_2_BASEADDR
#define DCC_IP_BASEADDR         XPAR_CENTRALE_DCC_V1_0_0_BASEADDR

/* Offsets des registres de l'IP DCC */
#define DCC_REG0_OFFSET  0x00
#define DCC_REG1_OFFSET  0x04

/* Bouton de validation (btnR = bit 3 du GPIO boutons sur Basys3) */
#define BTN_RIGHT  0x08

/*---------------------------------------------------------------------------
 * Instances
 *---------------------------------------------------------------------------*/
XGpio GpioSwitches;
XGpio GpioButtons;
XGpio GpioLeds;

/* Buffer de reception UART */
#define UART_BUF_SIZE 64
static char uart_buf[UART_BUF_SIZE];
static int  uart_idx = 0;

/*---------------------------------------------------------------------------
 * DCC 28-step speed encoding
 *
 * Convertit un step (0-28) et une direction en octet de commande DCC.
 * Format : 01DXXXXX
 *   D = 1 pour avant, 0 pour arriere
 *   XXXXX = encodage 28 steps selon la norme NMRA
 *
 * La table de correspondance NMRA est :
 *   step 0 = stop (00000)
 *   step 1-28 : adj = step + 3,
 *     bits[3:0] = adj >> 1, bit[4] = adj & 1
 *---------------------------------------------------------------------------*/
static u8 encode_speed_28(u8 step, u8 forward)
{
    u8 base = forward ? 0x60 : 0x40;
    if (step == 0)
        return base; /* stop */
    u8 adj = step + 3;
    u8 field = ((adj >> 1) & 0x0F) | ((adj & 0x01) << 4);
    return base | field;
}

/*---------------------------------------------------------------------------
 * Construction de trames DCC (reprises de main.c original)
 *---------------------------------------------------------------------------*/
static void build_frame_1byte(u8 addr, u8 cmd, u32 frame[2])
{
    u8 ctrl = addr ^ cmd;
    u64 trame = 0;

    trame = 0x7FFFFFULL;    /* Preambule : 23 bits de 1 */
    trame <<= 1;            /* start bit = 0 */
    trame <<= 8;
    trame |= (u64)addr;
    trame <<= 1;            /* start bit = 0 */
    trame <<= 8;
    trame |= (u64)cmd;
    trame <<= 1;            /* start bit = 0 */
    trame <<= 8;
    trame |= (u64)ctrl;
    trame <<= 1;
    trame |= 1;             /* stop bit = 1 */

    frame[0] = (u32)(trame & 0xFFFFFFFFULL);
    frame[1] = (u32)((trame >> 32) & 0x0007FFFFULL);
}

static void build_frame_2bytes(u8 addr, u8 cmd1, u8 cmd2, u32 frame[2])
{
    u8 ctrl = addr ^ cmd1 ^ cmd2;
    u64 trame = 0;

    trame = 0x3FFFULL;      /* Preambule standard : 14 bits de 1 */
    trame <<= 1;
    trame <<= 8;
    trame |= (u64)addr;
    trame <<= 1;
    trame <<= 8;
    trame |= (u64)cmd1;
    trame <<= 1;
    trame <<= 8;
    trame |= (u64)cmd2;
    trame <<= 1;
    trame <<= 8;
    trame |= (u64)ctrl;
    trame <<= 1;
    trame |= 1;

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
 * Utilitaires de parsing (pas de sscanf sur MicroBlaze minimal)
 *---------------------------------------------------------------------------*/

/* Parse un entier decimal depuis une chaine, retourne le nombre de chars lus */
static int parse_int(const char *s, int *out)
{
    int val = 0;
    int len = 0;
    while (s[len] >= '0' && s[len] <= '9') {
        val = val * 10 + (s[len] - '0');
        len++;
    }
    *out = val;
    return len;
}

/* Verifie si la chaine commence par le prefixe donne */
static int starts_with(const char *str, const char *prefix)
{
    while (*prefix) {
        if (*str != *prefix) return 0;
        str++;
        prefix++;
    }
    return 1;
}

/*---------------------------------------------------------------------------
 * Traitement d'une commande UART
 *---------------------------------------------------------------------------*/
static void process_uart_command(char *line)
{
    u32 frame[2];
    int addr_int, step_int;
    u8 addr, cmd;

    /* CMD:PING */
    if (starts_with(line, "CMD:PING")) {
        xil_printf("PONG\r\n");
        return;
    }

    /* CMD:FWD:<addr>:<step> */
    if (starts_with(line, "CMD:FWD:")) {
        const char *p = line + 8;
        p += parse_int(p, &addr_int);
        if (*p == ':') p++;
        parse_int(p, &step_int);
        addr = (u8)addr_int;
        cmd = encode_speed_28((u8)step_int, 1);
        build_frame_1byte(addr, cmd, frame);
        dcc_send_frame(frame);
        xil_printf("OK:FWD:%d:%d\r\n", addr_int, step_int);
        return;
    }

    /* CMD:REV:<addr>:<step> */
    if (starts_with(line, "CMD:REV:")) {
        const char *p = line + 8;
        p += parse_int(p, &addr_int);
        if (*p == ':') p++;
        parse_int(p, &step_int);
        addr = (u8)addr_int;
        cmd = encode_speed_28((u8)step_int, 0);
        build_frame_1byte(addr, cmd, frame);
        dcc_send_frame(frame);
        xil_printf("OK:REV:%d:%d\r\n", addr_int, step_int);
        return;
    }

    /* CMD:STOP:<addr> */
    if (starts_with(line, "CMD:STOP:")) {
        parse_int(line + 9, &addr_int);
        addr = (u8)addr_int;
        build_frame_1byte(addr, 0x60, frame);
        dcc_send_frame(frame);
        xil_printf("OK:STOP:%d\r\n", addr_int);
        return;
    }

    /* CMD:F0ON:<addr> */
    if (starts_with(line, "CMD:F0ON:")) {
        parse_int(line + 9, &addr_int);
        addr = (u8)addr_int;
        build_frame_1byte(addr, 0x90, frame);
        dcc_send_frame(frame);
        xil_printf("OK:F0ON:%d\r\n", addr_int);
        return;
    }

    /* CMD:F0OFF:<addr> */
    if (starts_with(line, "CMD:F0OFF:")) {
        parse_int(line + 10, &addr_int);
        addr = (u8)addr_int;
        build_frame_1byte(addr, 0x80, frame);
        dcc_send_frame(frame);
        xil_printf("OK:F0OFF:%d\r\n", addr_int);
        return;
    }

    /* CMD:F11ON:<addr> */
    if (starts_with(line, "CMD:F11ON:")) {
        parse_int(line + 10, &addr_int);
        addr = (u8)addr_int;
        build_frame_1byte(addr, 0xA4, frame);
        dcc_send_frame(frame);
        xil_printf("OK:F11ON:%d\r\n", addr_int);
        return;
    }

    /* CMD:F11OFF:<addr> */
    if (starts_with(line, "CMD:F11OFF:")) {
        parse_int(line + 11, &addr_int);
        addr = (u8)addr_int;
        build_frame_1byte(addr, 0xA0, frame);
        dcc_send_frame(frame);
        xil_printf("OK:F11OFF:%d\r\n", addr_int);
        return;
    }

    /* CMD:F13ON:<addr> */
    if (starts_with(line, "CMD:F13ON:")) {
        parse_int(line + 10, &addr_int);
        addr = (u8)addr_int;
        build_frame_2bytes(addr, 0xDE, 0x01, frame);
        dcc_send_frame(frame);
        xil_printf("OK:F13ON:%d\r\n", addr_int);
        return;
    }

    /* CMD:F13OFF:<addr> */
    if (starts_with(line, "CMD:F13OFF:")) {
        parse_int(line + 11, &addr_int);
        addr = (u8)addr_int;
        build_frame_2bytes(addr, 0xDE, 0x00, frame);
        dcc_send_frame(frame);
        xil_printf("OK:F13OFF:%d\r\n", addr_int);
        return;
    }

    xil_printf("ERR:UNKNOWN\r\n");
}

/*---------------------------------------------------------------------------
 * Lecture UART non-bloquante et accumulation dans le buffer
 *---------------------------------------------------------------------------*/
static void uart_poll(void)
{
    u8 byte;

    /* Lire tant qu'il y a des donnees disponibles */
    while (XUartLite_Recv(&UartLiteInst, &byte, 1) == 1) {
        if (byte == '\n' || byte == '\r') {
            if (uart_idx > 0) {
                uart_buf[uart_idx] = '\0';
                process_uart_command(uart_buf);
                uart_idx = 0;
            }
        } else if (uart_idx < UART_BUF_SIZE - 1) {
            uart_buf[uart_idx++] = (char)byte;
        }
    }
}

/*---------------------------------------------------------------------------
 * Construction de commande depuis les interrupteurs (fallback)
 *---------------------------------------------------------------------------*/
static void build_command(u8 addr, u8 switches, u32 frame[2])
{
    if (switches & 0x80)
        build_frame_1byte(addr, 0x76, frame);       /* Avant step 10 */
    else if (switches & 0x40)
        build_frame_1byte(addr, 0x56, frame);       /* Arriere step 10 */
    else if (switches & 0x20)
        build_frame_1byte(addr, 0x90, frame);       /* Phares ON */
    else if (switches & 0x10)
        build_frame_1byte(addr, 0x80, frame);       /* Phares OFF */
    else if (switches & 0x08)
        build_frame_1byte(addr, 0xA4, frame);       /* F11 ON */
    else if (switches & 0x04)
        build_frame_1byte(addr, 0xA0, frame);       /* F11 OFF */
    else if (switches & 0x02)
        build_frame_2bytes(addr, 0xDE, 0x01, frame);/* F13 ON */
    else if (switches & 0x01)
        build_frame_2bytes(addr, 0xDE, 0x00, frame);/* F13 OFF */
    else
        build_frame_1byte(addr, 0x60, frame);       /* Stop */
}

/*---------------------------------------------------------------------------
 * Programme principal
 *---------------------------------------------------------------------------*/

/* Instance UartLite globale pour uart_poll */
XUartLite UartLiteInst;

int main(void)
{
    u32 switches;
    u32 buttons;
    u8  addr;
    u8  cmd_switches;
    u32 frame[2];
    u32 btn_prev = 0;

    xil_printf("=== Centrale DCC -- MicroBlaze + UART ===\r\n");

    /* Initialisation UART */
    XUartLite_Initialize(&UartLiteInst, XPAR_AXI_UARTLITE_0_DEVICE_ID);

    /* Initialisation des GPIO */
    XGpio_Initialize(&GpioSwitches, XPAR_AXI_GPIO_0_DEVICE_ID);
    XGpio_Initialize(&GpioButtons,  XPAR_AXI_GPIO_1_DEVICE_ID);
    XGpio_Initialize(&GpioLeds,     XPAR_AXI_GPIO_2_DEVICE_ID);

    /* Configuration des directions (1 = entree, 0 = sortie) */
    XGpio_SetDataDirection(&GpioSwitches, 1, 0xFFFF);
    XGpio_SetDataDirection(&GpioButtons,  1, 0x1F);
    XGpio_SetDataDirection(&GpioLeds,     1, 0x0000);

    /* Trame initiale : arret du train adresse 3 */
    build_frame_1byte(3, 0x60, frame);
    dcc_send_frame(frame);
    xil_printf("Trame initiale envoyee (arret train 3)\r\n");

    /* Boucle principale (polling) */
    while (1) {
        /* ---- Commandes UART ---- */
        uart_poll();

        /* ---- Commandes par interrupteurs (fallback) ---- */
        switches = XGpio_DiscreteRead(&GpioSwitches, 1);
        buttons  = XGpio_DiscreteRead(&GpioButtons,  1);

        addr = (u8)((switches >> 12) & 0x0F);
        if (addr == 0) addr = 3;

        cmd_switches = (u8)(switches & 0xFF);
        XGpio_DiscreteWrite(&GpioLeds, 1, (u32)cmd_switches);

        /* Detection du front montant de btnR */
        if ((buttons & BTN_RIGHT) && !(btn_prev & BTN_RIGHT)) {
            build_command(addr, cmd_switches, frame);
            dcc_send_frame(frame);
            xil_printf("OK:SW:addr=%d,SW=0x%02X\r\n", addr, cmd_switches);
        }

        btn_prev = buttons;
    }

    return 0;
}
