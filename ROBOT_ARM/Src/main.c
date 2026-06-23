#include <stdint.h>

// ============================================================
// REGISTER TANIMLARI
// ============================================================
#define RCC_BASE      (0x40023800)
#define RCC_AHB1ENR   (*(volatile uint32_t*)(RCC_BASE + 0x30))
#define RCC_APB1ENR   (*(volatile uint32_t*)(RCC_BASE + 0x40))

#define GPIOA_BASE    (0x40020000)
#define GPIOA_MODER   (*(volatile uint32_t*)(GPIOA_BASE + 0x00))
#define GPIOA_AFRL    (*(volatile uint32_t*)(GPIOA_BASE + 0x20))

#define GPIOB_BASE    (0x40020400)
#define GPIOB_MODER   (*(volatile uint32_t*)(GPIOB_BASE + 0x00))
#define GPIOB_AFRH    (*(volatile uint32_t*)(GPIOB_BASE + 0x24))

#define USART3_BASE   (0x40004800)
#define USART3_SR     (*(volatile uint32_t*)(USART3_BASE + 0x00))
#define USART3_DR     (*(volatile uint32_t*)(USART3_BASE + 0x04))
#define USART3_BRR    (*(volatile uint32_t*)(USART3_BASE + 0x08))
#define USART3_CR1    (*(volatile uint32_t*)(USART3_BASE + 0x0C))

#define TIM2_BASE     (0x40000000)
#define TIM2_CR1      (*(volatile uint32_t*)(TIM2_BASE + 0x00))
#define TIM2_DIER     (*(volatile uint32_t*)(TIM2_BASE + 0x0C))
#define TIM2_SR       (*(volatile uint32_t*)(TIM2_BASE + 0x10))
#define TIM2_CCMR1    (*(volatile uint32_t*)(TIM2_BASE + 0x18))
#define TIM2_CCMR2    (*(volatile uint32_t*)(TIM2_BASE + 0x1C))
#define TIM2_CCER     (*(volatile uint32_t*)(TIM2_BASE + 0x20))
#define TIM2_PSC      (*(volatile uint32_t*)(TIM2_BASE + 0x28))
#define TIM2_ARR      (*(volatile uint32_t*)(TIM2_BASE + 0x2C))
#define TIM2_CCR1     (*(volatile uint32_t*)(TIM2_BASE + 0x34))
#define TIM2_CCR3     (*(volatile uint32_t*)(TIM2_BASE + 0x3C))
#define TIM2_CCR4     (*(volatile uint32_t*)(TIM2_BASE + 0x40))

#define SCB_CPACR     (*(volatile uint32_t*)(0xE000ED88))
#define NVIC_ISER0    (*(volatile uint32_t*)(0xE000E100))
#define NVIC_ISER1    (*(volatile uint32_t*)(0xE000E104))

// ============================================================
// SABİTLER
// ============================================================
#define PI           3.14159265f
#define UPPER_LENGTH 18.0f
#define LOWER_LENGTH 18.0f
#define PWM_HOME     1500
#define PWM_MIN       500
#define PWM_MAX      2500

// ============================================================
// GLOBAL DEĞİŞKENLER
// ============================================================
uint32_t hedef_hip_pwm    = PWM_HOME;
uint32_t hedef_omuz_pwm   = PWM_HOME;
uint32_t hedef_dirsek_pwm = PWM_HOME;
uint32_t mevcut_hip_pwm    = PWM_HOME;
uint32_t mevcut_omuz_pwm   = PWM_HOME;
uint32_t mevcut_dirsek_pwm = PWM_HOME;

char     rx_buffer[64];
char     cmd_buffer[64];
volatile uint8_t rx_index    = 0;
volatile uint8_t komut_geldi = 0;
volatile uint8_t mesgul      = 0;


volatile uint8_t  interp_aktif       = 0;
volatile uint32_t interp_adim        = 0;
volatile uint32_t interp_toplam      = 0;
volatile float    interp_step_hip    = 0.0f;
volatile float    interp_step_omuz   = 0.0f;
volatile float    interp_step_dirsek = 0.0f;
volatile uint32_t interp_h_hip       = PWM_HOME;
volatile uint32_t interp_h_omuz      = PWM_HOME;
volatile uint32_t interp_h_dirsek    = PWM_HOME;

// ============================================================
// MATEMATİK
// ============================================================
float custom_sqrt(float number) {
    if (number <= 0.0f) return 0.0f;
    long i; float x2, y;
    x2 = number * 0.5f; y = number;
    i  = *(long*)&y;
    i  = 0x5f3759df - (i >> 1);
    y  = *(float*)&i;
    y  = y * (1.5f - (x2 * y * y));
    y  = y * (1.5f - (x2 * y * y));
    return number * y;
}

float custom_atan2(float y, float x) {
    float abs_y = y < 0.0f ? -y : y;
    float abs_x = x < 0.0f ? -x : x;
    if (abs_x == 0.0f && abs_y == 0.0f) return 0.0f;
    float mn = abs_x < abs_y ? abs_x : abs_y;
    float mx = abs_x > abs_y ? abs_x : abs_y;
    float a  = mn / mx; float s = a * a;
    float r  = ((-0.0464964749f * s + 0.15931422f) * s - 0.327622764f) * s * a + a;
    if (abs_y > abs_x) r = 1.57079632679f - r;
    if (x < 0.0f)      r = 3.14159265359f - r;
    if (y < 0.0f)      r = -r;
    return r;
}

float custom_acos(float x) {
    float negate = (float)(x < 0);
    x = x < 0.0f ? -x : x;
    float ret = -0.0187293f;
    ret = ret * x + 0.0742610f;
    ret = ret * x - 0.2121144f;
    ret = ret * x + 1.5707288f;
    ret = ret * custom_sqrt(1.0f - x);
    return (negate * PI) + (ret - 2.0f * negate * ret);
}

// ============================================================
// UART
// ============================================================

void uart_send_str(const char* s) {
    while (*s) {
        while (!(USART3_SR & (1 << 7)));
        USART3_DR = *s++;
    }
}

void uart_send_int(uint32_t val) {
    char buf[10]; int i = 9;
    buf[i] = '\0';
    if (val == 0) { buf[--i] = '0'; }
    else { while (val > 0) { buf[--i] = '0' + (val % 10); val /= 10; } }
    uart_send_str(&buf[i]);
}

// ============================================================
// BARE-METAL PARSER
// ============================================================

static int parse_int_p(const char** p) {
    int val = 0;
    while (**p >= '0' && **p <= '9') {
        val = val * 10 + (**p - '0');
        (*p)++;
    }
    return val;
}

static float parse_float(const char* p) {
    float sign = 1.0f;
    if      (*p == '-') { sign = -1.0f; p++; }
    else if (*p == '+') { p++; }
    float val = (float)parse_int_p(&p);
    if (*p == '.') {
        p++;
        float frac = 0.0f, div = 10.0f;
        while (*p >= '0' && *p <= '9') {
            frac += (*p - '0') / div;
            div  *= 10.0f;
            p++;
        }
        val += frac;
    }
    return sign * val;
}

static float parse_param(const char* buf, char param) {
    const char* p = buf;
    while (*p) {
        if (*p == param) {
            p++;
            while (*p == ' ') p++;
            if (*p == '-' || *p == '+' || (*p >= '0' && *p <= '9'))
                return parse_float(p);
        }
        p++;
    }
    return -9999.0f;
}

// ============================================================
// TERS KİNEMATİK
// ============================================================
void ik_calc_2D(float R, float z) {
    float dist_sq = (R * R) + (z * z);
    float dist    = custom_sqrt(dist_sq);

    float maxReach = (UPPER_LENGTH + LOWER_LENGTH) - 0.1f;
    if (dist > maxReach) dist = maxReach;
    if (dist < 1.0f)     dist = 1.0f;

    float alpha1     = custom_atan2(z, R);
    float cos_alpha2 = ((UPPER_LENGTH * UPPER_LENGTH) + (dist * dist)
                       - (LOWER_LENGTH * LOWER_LENGTH))
                       / (2.0f * UPPER_LENGTH * dist);
    if (cos_alpha2 >  1.0f) cos_alpha2 =  1.0f;
    if (cos_alpha2 < -1.0f) cos_alpha2 = -1.0f;
    float shoulderDeg = (alpha1 + custom_acos(cos_alpha2)) * (180.0f / PI);

    float cos_beta = ((UPPER_LENGTH * UPPER_LENGTH) + (LOWER_LENGTH * LOWER_LENGTH)
                     - (dist * dist))
                     / (2.0f * UPPER_LENGTH * LOWER_LENGTH);
    if (cos_beta >  1.0f) cos_beta =  1.0f;
    if (cos_beta < -1.0f) cos_beta = -1.0f;
    float elbowDeg = custom_acos(cos_beta) * (180.0f / PI);

    hedef_omuz_pwm   = 500 + (uint32_t)((shoulderDeg * 2000.0f) / 180.0f);
    hedef_dirsek_pwm =  2500 - (uint32_t)((elbowDeg    * 2000.0f) / 180.0f);
}

// ============================================================
// İNTERPOLASYON BAŞLAT
// ============================================================
void interpolation_baslat(uint32_t h_hip, uint32_t h_omuz,
                           uint32_t h_dirsek, uint32_t adim) {
    interp_h_hip    = h_hip;
    interp_h_omuz   = h_omuz;
    interp_h_dirsek = h_dirsek;
    interp_toplam   = adim;
    interp_adim     = 0;

    interp_step_hip    = (float)((int32_t)h_hip    - (int32_t)mevcut_hip_pwm)    / (float)adim;
    interp_step_omuz   = (float)((int32_t)h_omuz   - (int32_t)mevcut_omuz_pwm)   / (float)adim;
    interp_step_dirsek = (float)((int32_t)h_dirsek - (int32_t)mevcut_dirsek_pwm) / (float)adim;

    interp_aktif = 1;
}

// ============================================================
// TIM2 UPDATE INTERRUPT
// ============================================================
void TIM2_IRQHandler(void) {
    TIM2_SR &= ~(1 << 0);   // update flag temizle

    if (!interp_aktif) return;

    if (interp_adim < interp_toplam) {
        mevcut_hip_pwm    = (uint32_t)((float)mevcut_hip_pwm    + interp_step_hip);
        mevcut_omuz_pwm   = (uint32_t)((float)mevcut_omuz_pwm   + interp_step_omuz);
        mevcut_dirsek_pwm = (uint32_t)((float)mevcut_dirsek_pwm + interp_step_dirsek);

        TIM2_CCR1 = mevcut_hip_pwm;
        TIM2_CCR3 = mevcut_omuz_pwm;
        TIM2_CCR4 = mevcut_dirsek_pwm;

        interp_adim++;
    } else {
        // Hedefe kilitle
        mevcut_hip_pwm    = interp_h_hip;
        mevcut_omuz_pwm   = interp_h_omuz;
        mevcut_dirsek_pwm = interp_h_dirsek;

        TIM2_CCR1 = interp_h_hip;
        TIM2_CCR3 = interp_h_omuz;
        TIM2_CCR4 = interp_h_dirsek;

        interp_aktif = 0;
        mesgul       = 0;
        uart_send_str("OK\r\n");
    }
}

// ============================================================
// USART3 KESMESİ
// ============================================================
void USART3_IRQHandler(void) {
    if (USART3_SR & (1 << 5)) {
        char c = (char)USART3_DR;
        if (c == '\n' || c == '\r') {
            if (rx_index > 0) {
                rx_buffer[rx_index] = '\0';
                komut_geldi = 1;
            }
        } else if (rx_index < 63) {
            rx_buffer[rx_index++] = c;
        }
    }
}

// ============================================================
// G-CODE İŞLEYİCİ
// ============================================================

void gcode_isle(char* buf) {

    // G28 — Home
    if (buf[0]=='G' && buf[1]=='2' && buf[2]=='8') {
        hedef_hip_pwm = hedef_omuz_pwm = hedef_dirsek_pwm = PWM_HOME;
        mesgul = 1;
        interpolation_baslat(PWM_HOME, PWM_HOME, PWM_HOME, 50);
        uart_send_str("OK HOME\r\n");
        return;
    }

    // M114 — Pozisyon raporu
    if (buf[0]=='M' && buf[1]=='1' && buf[2]=='1' && buf[3]=='4') {
        uart_send_str("H:"); uart_send_int(mevcut_hip_pwm);
        uart_send_str(" O:"); uart_send_int(mevcut_omuz_pwm);
        uart_send_str(" D:"); uart_send_int(mevcut_dirsek_pwm);
        uart_send_str("\r\n");
        return;
    }

    // G0 / G1 — Hareket
    if (buf[0]=='G' && (buf[1]=='0' || buf[1]=='1')) {
        float R       = parse_param(buf, 'X');
        float z       = parse_param(buf, 'Y');
        float hip_deg = parse_param(buf, 'Z');

        if (R > -9000.0f && z > -9000.0f)
            ik_calc_2D(R, z);

        if (hip_deg > -9000.0f) {
            if (hip_deg <   0.0f) hip_deg =   0.0f;
            if (hip_deg > 180.0f) hip_deg = 180.0f;
            hedef_hip_pwm = 500 + (uint32_t)((hip_deg * 2000.0f) / 180.0f);
        }

        mesgul = 1;
        interpolation_baslat(hedef_hip_pwm, hedef_omuz_pwm, hedef_dirsek_pwm, 20);
        // OK cevabı hareket bitince TIM2_IRQHandler'dan gelir
        return;
    }

    uart_send_str("ERR\r\n");
}

// ============================================================
// MAIN
// ============================================================
int main(void) {
    SCB_CPACR |= (0xF << 20);            // FPU aktif

    RCC_AHB1ENR |= (1 << 0) | (1 << 1); // GPIOA + GPIOB
    RCC_APB1ENR |= (1 << 0) | (1 << 18);// TIM2 + USART3

    // PA0=TIM2_CH1(hip), PA2=TIM2_CH3(omuz), PA3=TIM2_CH4(dirsek) → AF1
    GPIOA_MODER |= (2 << 0) | (2 << 4) | (2 << 6);
    GPIOA_AFRL  |= (1 << 0) | (1 << 8) | (1 << 12);

    // PB10=USART3_TX, PB11=USART3_RX → AF7
    GPIOB_MODER |= (2 << 20) | (2 << 22);
    GPIOB_AFRH  |= (7 << 8)  | (7 << 12);

    // USART3: 16MHz HSI, 115200 baud
    USART3_BRR  = 0x008B;
    USART3_CR1 |= (1 << 2) | (1 << 3) | (1 << 5) | (1 << 13);
    NVIC_ISER1 |= (1 << 7);             // USART3 IRQ=39 → ISER1 bit7

    // TIM2: 16MHz/16=1MHz tick, ARR=20000 → 50Hz PWM
    TIM2_PSC    = 16 - 1;
    TIM2_ARR    = 20000 - 1;
    TIM2_CCMR1 |= (6 << 4)  | (1 << 3);              // CH1 PWM mode1
    TIM2_CCMR2 |= (6 << 4)  | (1 << 3)               // CH3 PWM mode1
               |  (6 << 12) | (1 << 11);              // CH4 PWM mode1
    TIM2_CCER  |= (1 << 0) | (1 << 8) | (1 << 12);   // CH1,CH3,CH4 aktif
    TIM2_DIER  |= (1 << 0);                           // Update interrupt
    NVIC_ISER0 |= (1 << 28);                          // TIM2 IRQ=28 → ISER0 bit28
    TIM2_CR1   |= (1 << 0);                           // Timer başlat

    // Motorları home'a al
    TIM2_CCR1 = PWM_HOME;
    TIM2_CCR3 = PWM_HOME;
    TIM2_CCR4 = PWM_HOME;

    uart_send_str("READY\r\n");

    while (1) {
        if (komut_geldi && !mesgul) {
            uint8_t i = 0;
            while (rx_buffer[i]) { cmd_buffer[i] = rx_buffer[i]; i++; }
            cmd_buffer[i] = '\0';
            rx_index    = 0;
            komut_geldi = 0;
            gcode_isle(cmd_buffer);

        } else if (komut_geldi && mesgul) {
            uart_send_str("BUSY\r\n");
            rx_index    = 0;
            komut_geldi = 0;
        }
    }
}
