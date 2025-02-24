/* ANSI-C code produced by gperf version 3.1 */
/* Command-line: gperf -tc7 --output-file=parse_mnemonic.c parse_mnemonic.gperf  */
/* Computed positions: -k'1-4' */

#if !((' ' == 32) && ('!' == 33) && ('"' == 34) && ('#' == 35) \
      && ('%' == 37) && ('&' == 38) && ('\'' == 39) && ('(' == 40) \
      && (')' == 41) && ('*' == 42) && ('+' == 43) && (',' == 44) \
      && ('-' == 45) && ('.' == 46) && ('/' == 47) && ('0' == 48) \
      && ('1' == 49) && ('2' == 50) && ('3' == 51) && ('4' == 52) \
      && ('5' == 53) && ('6' == 54) && ('7' == 55) && ('8' == 56) \
      && ('9' == 57) && (':' == 58) && (';' == 59) && ('<' == 60) \
      && ('=' == 61) && ('>' == 62) && ('?' == 63) && ('A' == 65) \
      && ('B' == 66) && ('C' == 67) && ('D' == 68) && ('E' == 69) \
      && ('F' == 70) && ('G' == 71) && ('H' == 72) && ('I' == 73) \
      && ('J' == 74) && ('K' == 75) && ('L' == 76) && ('M' == 77) \
      && ('N' == 78) && ('O' == 79) && ('P' == 80) && ('Q' == 81) \
      && ('R' == 82) && ('S' == 83) && ('T' == 84) && ('U' == 85) \
      && ('V' == 86) && ('W' == 87) && ('X' == 88) && ('Y' == 89) \
      && ('Z' == 90) && ('[' == 91) && ('\\' == 92) && (']' == 93) \
      && ('^' == 94) && ('_' == 95) && ('a' == 97) && ('b' == 98) \
      && ('c' == 99) && ('d' == 100) && ('e' == 101) && ('f' == 102) \
      && ('g' == 103) && ('h' == 104) && ('i' == 105) && ('j' == 106) \
      && ('k' == 107) && ('l' == 108) && ('m' == 109) && ('n' == 110) \
      && ('o' == 111) && ('p' == 112) && ('q' == 113) && ('r' == 114) \
      && ('s' == 115) && ('t' == 116) && ('u' == 117) && ('v' == 118) \
      && ('w' == 119) && ('x' == 120) && ('y' == 121) && ('z' == 122) \
      && ('{' == 123) && ('|' == 124) && ('}' == 125) && ('~' == 126))
/* The character set is not based on ISO-646.  */
#error "gperf generated tables don't work with this execution character set. Please report a bug to <bug-gperf@gnu.org>."
#endif

#line 1 "parse_mnemonic.gperf"

#include "stddef.h"
#include "string.h"

enum Mnemonic {
    INVALID,
    LD, LDB, LDSB, LDH, LDSH,
    ST, STB, STSB, STH, STSH,
    SMV, SST, SCL,
    ADD, ADC, SUB, SBC, AND, OR, XOR, BTC, NOT,
    ADDX, ADCX, SUBX, SBCX, ANDX, ORX, XORX, BTCX, NOTX,
    LSL, LSR, ASR, LSLX,
    TST, TEQ, CMP, CPN,
    BEQ, BNE, BCS, BCC, BMI, BPL, BVS, BVC, BHI, BLS, BGE, BLT, BGT, BLE, B,
    BLEQ, BLNE, BLCS, BLCC, BLMI, BLPL, BLVS, BLVC, BLHI, BLLS, BLGE, BLLT, BLGT, BLLE, BL,
    MVI, SWI,
    MOV, MOV32,
    NOP,
};


#line 23 "parse_mnemonic.gperf"
struct mnemonic_token {
    char* name;
    enum Mnemonic mnemonic;
};

#define TOTAL_KEYWORDS 147
#define MIN_WORD_LENGTH 1
#define MAX_WORD_LENGTH 5
#define MIN_HASH_VALUE 7
#define MAX_HASH_VALUE 449
/* maximum key range = 443, duplicates = 0 */

#ifdef __GNUC__
__inline
#else
#ifdef __cplusplus
inline
#endif
#endif
static unsigned int
hash (register const char *str, register size_t len)
{
  static unsigned short asso_values[] =
    {
      450, 450, 450, 450, 450, 450, 450, 450, 450, 450,
      450, 450, 450, 450, 450, 450, 450, 450, 450, 450,
      450, 450, 450, 450, 450, 450, 450, 450, 450, 450,
      450, 450, 450, 450, 450, 450, 450, 450, 450, 450,
      450, 450, 450, 450, 450, 450, 450, 450, 450, 450,
      450,   0, 450, 450, 450, 450, 450, 450, 450, 450,
      450, 450, 450, 450, 450, 150,  25,  65,  30,  40,
       39, 135,   8, 205, 135, 450,  10, 110,  25,  85,
      180, 210,  74,  20,   0, 165,  74, 150,  60,   0,
      450, 450, 450, 450, 450, 450, 450,  90,  15,  55,
       10,  50,  44, 175, 224, 150, 125, 450,   0,  35,
        5,  45,   4, 205,  44,   5,   0, 120,  54, 220,
       65,  30, 450, 450, 450, 450, 450, 450, 450
    };
  register unsigned int hval = len;

  switch (hval)
    {
      default:
        hval += asso_values[(unsigned char)str[3]];
      /*FALLTHROUGH*/
      case 3:
        hval += asso_values[(unsigned char)str[2]+1];
      /*FALLTHROUGH*/
      case 2:
        hval += asso_values[(unsigned char)str[1]];
      /*FALLTHROUGH*/
      case 1:
        hval += asso_values[(unsigned char)str[0]];
        break;
    }
  return hval;
}

struct mnemonic_token *
in_word_set (register const char *str, register size_t len)
{
  static struct mnemonic_token wordlist[] =
    {
      {""}, {""}, {""}, {""}, {""}, {""}, {""},
#line 33 "parse_mnemonic.gperf"
      {"st",    ST},
      {""}, {""}, {""}, {""},
#line 28 "parse_mnemonic.gperf"
      {"ld",    LD},
#line 91 "parse_mnemonic.gperf"
      {"lsr",   LSR},
      {""}, {""},
#line 58 "parse_mnemonic.gperf"
      {"b",     B},
#line 73 "parse_mnemonic.gperf"
      {"bl",    BL},
#line 68 "parse_mnemonic.gperf"
      {"bls",   BLS},
      {""}, {""}, {""},
#line 107 "parse_mnemonic.gperf"
      {"ST",    ST},
      {""},
#line 35 "parse_mnemonic.gperf"
      {"stsb",  STSB},
      {""},
#line 131 "parse_mnemonic.gperf"
      {"B",     B},
      {""},
#line 48 "parse_mnemonic.gperf"
      {"btc",   BTC},
#line 30 "parse_mnemonic.gperf"
      {"ldsb",  LDSB},
      {""}, {""},
#line 111 "parse_mnemonic.gperf"
      {"STSH",  STSH},
#line 44 "parse_mnemonic.gperf"
      {"sbc",   SBC},
#line 76 "parse_mnemonic.gperf"
      {"blcs",  BLCS},
      {""}, {""},
#line 146 "parse_mnemonic.gperf"
      {"BL",    BL},
#line 141 "parse_mnemonic.gperf"
      {"BLS",   BLS},
      {""}, {""}, {""},
#line 102 "parse_mnemonic.gperf"
      {"LD",    LD},
#line 90 "parse_mnemonic.gperf"
      {"lsl",   LSL},
      {""}, {""}, {""},
#line 159 "parse_mnemonic.gperf"
      {"BLGT",  BLGT},
      {""},
#line 109 "parse_mnemonic.gperf"
      {"STSB",  STSB},
      {""}, {""},
#line 106 "parse_mnemonic.gperf"
      {"LDSH",  LDSH},
#line 164 "parse_mnemonic.gperf"
      {"LSR",   LSR},
#line 85 "parse_mnemonic.gperf"
      {"bllt",  BLLT},
      {""}, {""},
#line 64 "parse_mnemonic.gperf"
      {"bpl",   BPL},
#line 122 "parse_mnemonic.gperf"
      {"BTC",   BTC},
#line 83 "parse_mnemonic.gperf"
      {"blls",  BLLS},
      {""}, {""},
#line 72 "parse_mnemonic.gperf"
      {"ble",   BLE},
#line 34 "parse_mnemonic.gperf"
      {"stb",   STB},
      {""}, {""}, {""},
#line 60 "parse_mnemonic.gperf"
      {"bne",   BNE},
#line 29 "parse_mnemonic.gperf"
      {"ldb",   LDB},
#line 104 "parse_mnemonic.gperf"
      {"LDSB",  LDSB},
      {""}, {""},
#line 65 "parse_mnemonic.gperf"
      {"bvs",   BVS},
#line 61 "parse_mnemonic.gperf"
      {"bcs",   BCS},
      {""}, {""}, {""},
#line 145 "parse_mnemonic.gperf"
      {"BLE",   BLE},
#line 118 "parse_mnemonic.gperf"
      {"SBC",   SBC},
      {""}, {""}, {""},
#line 66 "parse_mnemonic.gperf"
      {"bvc",   BVC},
#line 62 "parse_mnemonic.gperf"
      {"bcc",   BCC},
#line 77 "parse_mnemonic.gperf"
      {"blcc",  BLCC},
      {""}, {""},
#line 157 "parse_mnemonic.gperf"
      {"BLGE",  BLGE},
#line 108 "parse_mnemonic.gperf"
      {"STB",   STB},
#line 149 "parse_mnemonic.gperf"
      {"BLCS",  BLCS},
      {""},
#line 46 "parse_mnemonic.gperf"
      {"or",    OR},
#line 133 "parse_mnemonic.gperf"
      {"BNE",   BNE},
#line 134 "parse_mnemonic.gperf"
      {"BCS",   BCS},
#line 56 "parse_mnemonic.gperf"
      {"btcx",  BTCX},
      {""}, {""},
#line 95 "parse_mnemonic.gperf"
      {"teq",   TEQ},
#line 40 "parse_mnemonic.gperf"
      {"scl",   SCL},
#line 52 "parse_mnemonic.gperf"
      {"sbcx",  SBCX},
      {""}, {""},
#line 138 "parse_mnemonic.gperf"
      {"BVS",   BVS},
#line 92 "parse_mnemonic.gperf"
      {"asr",   ASR},
#line 87 "parse_mnemonic.gperf"
      {"blle",  BLLE},
      {""}, {""},
#line 97 "parse_mnemonic.gperf"
      {"cpn",   CPN},
#line 103 "parse_mnemonic.gperf"
      {"LDB",   LDB},
#line 93 "parse_mnemonic.gperf"
      {"lslx",  LSLX},
      {""}, {""},
#line 59 "parse_mnemonic.gperf"
      {"beq",   BEQ},
#line 42 "parse_mnemonic.gperf"
      {"adc",   ADC},
#line 75 "parse_mnemonic.gperf"
      {"blne",  BLNE},
      {""}, {""},
#line 168 "parse_mnemonic.gperf"
      {"TEQ",   TEQ},
#line 47 "parse_mnemonic.gperf"
      {"xor",   XOR},
#line 130 "parse_mnemonic.gperf"
      {"BTCX",  BTCX},
      {""}, {""},
#line 54 "parse_mnemonic.gperf"
      {"orx",   ORX},
#line 135 "parse_mnemonic.gperf"
      {"BCC",   BCC},
      {""}, {""}, {""}, {""},
#line 94 "parse_mnemonic.gperf"
      {"tst",   TST},
      {""}, {""}, {""},
#line 139 "parse_mnemonic.gperf"
      {"BVC",   BVC},
#line 39 "parse_mnemonic.gperf"
      {"sst",   SST},
#line 150 "parse_mnemonic.gperf"
      {"BLCC",  BLCC},
      {""}, {""}, {""},
#line 70 "parse_mnemonic.gperf"
      {"blt",   BLT},
#line 126 "parse_mnemonic.gperf"
      {"SBCX",  SBCX},
      {""}, {""},
#line 132 "parse_mnemonic.gperf"
      {"BEQ",   BEQ},
#line 163 "parse_mnemonic.gperf"
      {"LSL",   LSL},
      {""}, {""}, {""}, {""},
#line 45 "parse_mnemonic.gperf"
      {"and",   AND},
#line 158 "parse_mnemonic.gperf"
      {"BLLT",  BLLT},
      {""}, {""}, {""},
#line 41 "parse_mnemonic.gperf"
      {"add",   ADD},
      {""}, {""}, {""}, {""},
#line 36 "parse_mnemonic.gperf"
      {"sth",   STH},
      {""}, {""},
#line 120 "parse_mnemonic.gperf"
      {"OR",    OR},
#line 128 "parse_mnemonic.gperf"
      {"ORX",   ORX},
#line 31 "parse_mnemonic.gperf"
      {"ldh",   LDH},
#line 148 "parse_mnemonic.gperf"
      {"BLNE",  BLNE},
      {""}, {""}, {""},
#line 121 "parse_mnemonic.gperf"
      {"XOR",   XOR},
#line 156 "parse_mnemonic.gperf"
      {"BLLS",  BLLS},
      {""},
#line 140 "parse_mnemonic.gperf"
      {"BHI",   BHI},
      {""},
#line 98 "parse_mnemonic.gperf"
      {"not",   NOT},
#line 78 "parse_mnemonic.gperf"
      {"blmi",  BLMI},
      {""}, {""}, {""},
#line 63 "parse_mnemonic.gperf"
      {"bmi",   BMI},
#line 50 "parse_mnemonic.gperf"
      {"adcx",  ADCX},
      {""}, {""}, {""},
#line 43 "parse_mnemonic.gperf"
      {"sub",   SUB},
#line 55 "parse_mnemonic.gperf"
      {"xorx",  XORX},
      {""}, {""}, {""},
#line 167 "parse_mnemonic.gperf"
      {"TST",   TST},
#line 160 "parse_mnemonic.gperf"
      {"BLLE",  BLLE},
      {""}, {""}, {""},
#line 165 "parse_mnemonic.gperf"
      {"ASR",   ASR},
      {""}, {""}, {""}, {""},
#line 114 "parse_mnemonic.gperf"
      {"SCL",   SCL},
      {""}, {""}, {""},
#line 142 "parse_mnemonic.gperf"
      {"BGE",   BGE},
#line 143 "parse_mnemonic.gperf"
      {"BLT",   BLT},
#line 166 "parse_mnemonic.gperf"
      {"LSLX",  LSLX},
      {""}, {""}, {""},
#line 113 "parse_mnemonic.gperf"
      {"SST",   SST},
#line 153 "parse_mnemonic.gperf"
      {"BLVS",  BLVS},
      {""}, {""}, {""},
#line 116 "parse_mnemonic.gperf"
      {"ADC",   ADC},
#line 53 "parse_mnemonic.gperf"
      {"andx",  ANDX},
      {""}, {""},
#line 88 "parse_mnemonic.gperf"
      {"mvi",   MVI},
#line 119 "parse_mnemonic.gperf"
      {"AND",   AND},
#line 49 "parse_mnemonic.gperf"
      {"addx",  ADDX},
      {""}, {""}, {""},
#line 115 "parse_mnemonic.gperf"
      {"ADD",   ADD},
#line 79 "parse_mnemonic.gperf"
      {"blpl",  BLPL},
      {""}, {""}, {""},
#line 110 "parse_mnemonic.gperf"
      {"STH",   STH},
#line 129 "parse_mnemonic.gperf"
      {"XORX",  XORX},
      {""}, {""}, {""},
#line 37 "parse_mnemonic.gperf"
      {"stsh",  STSH},
      {""}, {""}, {""},
#line 69 "parse_mnemonic.gperf"
      {"bge",   BGE},
#line 32 "parse_mnemonic.gperf"
      {"ldsh",  LDSH},
#line 57 "parse_mnemonic.gperf"
      {"notx",  NOTX},
      {""}, {""}, {""},
#line 86 "parse_mnemonic.gperf"
      {"blgt",  BLGT},
#line 80 "parse_mnemonic.gperf"
      {"blvs",  BLVS},
      {""}, {""}, {""},
#line 105 "parse_mnemonic.gperf"
      {"LDH",   LDH},
#line 51 "parse_mnemonic.gperf"
      {"subx",  SUBX},
      {""}, {""}, {""},
#line 117 "parse_mnemonic.gperf"
      {"SUB",   SUB},
#line 154 "parse_mnemonic.gperf"
      {"BLVC",  BLVC},
      {""}, {""}, {""},
#line 101 "parse_mnemonic.gperf"
      {"nop",   NOP},
#line 152 "parse_mnemonic.gperf"
      {"BLPL",  BLPL},
      {""}, {""}, {""},
#line 38 "parse_mnemonic.gperf"
      {"smv",   SMV},
      {""}, {""}, {""}, {""},
#line 74 "parse_mnemonic.gperf"
      {"bleq",  BLEQ},
#line 151 "parse_mnemonic.gperf"
      {"BLMI",  BLMI},
      {""}, {""}, {""},
#line 136 "parse_mnemonic.gperf"
      {"BMI",   BMI},
#line 124 "parse_mnemonic.gperf"
      {"ADCX",  ADCX},
      {""}, {""}, {""},
#line 171 "parse_mnemonic.gperf"
      {"NOT",   NOT},
#line 127 "parse_mnemonic.gperf"
      {"ANDX",  ANDX},
      {""}, {""}, {""},
#line 112 "parse_mnemonic.gperf"
      {"SMV",   SMV},
#line 123 "parse_mnemonic.gperf"
      {"ADDX",  ADDX},
      {""}, {""}, {""},
#line 147 "parse_mnemonic.gperf"
      {"BLEQ",  BLEQ},
      {""}, {""}, {""}, {""},
#line 84 "parse_mnemonic.gperf"
      {"blge",  BLGE},
#line 81 "parse_mnemonic.gperf"
      {"blvc",  BLVC},
      {""}, {""}, {""},
#line 96 "parse_mnemonic.gperf"
      {"cmp",   CMP},
      {""}, {""}, {""}, {""},
#line 99 "parse_mnemonic.gperf"
      {"mov",   MOV},
      {""},
#line 100 "parse_mnemonic.gperf"
      {"mov32", MOV32},
      {""}, {""},
#line 162 "parse_mnemonic.gperf"
      {"SWI",   SWI},
      {""}, {""}, {""}, {""},
#line 71 "parse_mnemonic.gperf"
      {"bgt",   BGT},
#line 125 "parse_mnemonic.gperf"
      {"SUBX",  SUBX},
      {""}, {""}, {""},
#line 137 "parse_mnemonic.gperf"
      {"BPL",   BPL},
#line 82 "parse_mnemonic.gperf"
      {"blhi",  BLHI},
      {""}, {""},
#line 161 "parse_mnemonic.gperf"
      {"MVI",   MVI},
#line 174 "parse_mnemonic.gperf"
      {"NOP",   NOP},
      {""}, {""}, {""}, {""},
#line 144 "parse_mnemonic.gperf"
      {"BGT",   BGT},
      {""}, {""}, {""}, {""},
#line 170 "parse_mnemonic.gperf"
      {"CPN",   CPN},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""},
#line 172 "parse_mnemonic.gperf"
      {"MOV",   MOV},
      {""},
#line 173 "parse_mnemonic.gperf"
      {"MOV32", MOV32},
      {""}, {""},
#line 89 "parse_mnemonic.gperf"
      {"swi",   SWI},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""},
#line 67 "parse_mnemonic.gperf"
      {"bhi",   BHI},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""},
#line 169 "parse_mnemonic.gperf"
      {"CMP",   CMP},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""}, {""},
      {""}, {""}, {""}, {""}, {""}, {""},
#line 155 "parse_mnemonic.gperf"
      {"BLHI",  BLHI}
    };

  if (len <= MAX_WORD_LENGTH && len >= MIN_WORD_LENGTH)
    {
      register unsigned int key = hash (str, len);

      if (key <= MAX_HASH_VALUE)
        {
          register const char *s = wordlist[key].name;

          if (*str == *s && !strncmp (str + 1, s + 1, len - 1) && s[len] == '\0')
            return &wordlist[key];
        }
    }
  return 0;
}
#line 175 "parse_mnemonic.gperf"

enum Mnemonic parseMnemonic(register const char* str, register size_t len) {
    struct mnemonic_token * res = in_word_set(str, len);
    return (res) ? res->mnemonic : INVALID;
}
