#ifndef _driver_h
#define _driver_h

#include <stdlib.h>
#include <stdio.h>
#include <groonga.h>

#define MRN_MAX_KEY_LEN 1024
#define MRN_DB_FILE_PATH "groonga.db"
#define MRN_LOG_FILE_NAME "groonga.log"
#define MRN_LEXICON_TABLE_NAME "lexicon"

typedef unsigned char uchar;

typedef struct _mrn_charset_map
{
  const char *csname_mysql;
  grn_encoding csname_groonga;
} MRN_CHARSET_MAP;

typedef struct _mrn_field
{
  const char *name;
  uint name_len;
  grn_obj *obj;
  grn_obj *index;
  //grn_id gid;
  uint field_no;
} mrn_field;

typedef struct _mrn_table
{
  const char *name;
  uint name_len;
  uint use_count;
  grn_obj *obj;
  //grn_id gid;
  mrn_field **field;
  uint fields;
  uint pkey_field;
} mrn_table;


typedef struct _mrn_column_info
{
  const char *name;
  uint name_size;
  char *path;
  grn_obj_flags flags;
  grn_obj *type;
  grn_builtin_type gtype;
  grn_obj *obj;
} mrn_column_info;

typedef struct _mrn_table_info
{
  const char *name;
  uint name_size;
  char *path;
  grn_obj_flags flags;
  grn_obj *key_type;
  grn_obj *obj;
} mrn_table_info;

typedef struct _mrn_info
{
  mrn_table_info *table;
  mrn_column_info **columns;
  uint n_columns;
  uint ref_count;
  grn_table_cursor *cursor;
  grn_obj *res;
} mrn_info;

typedef struct _mrn_record
{
  mrn_info *info;
  const void *key;
  uint key_size;
  grn_obj **value;
  uint n_columns;
  uint actual_size;
  uchar *bitmap;
  grn_id id;
} mrn_record;

typedef enum {
  MRN_EXPR_UNKNOWN=0,
  MRN_EXPR_COLUMN=1,
  MRN_EXPR_AND=2,
  MRN_EXPR_OR=3,
  MRN_EXPR_EQ=4,
  MRN_EXPR_NOT_EQ=5,
  MRN_EXPR_GT=6,
  MRN_EXPR_GT_EQ=7,
  MRN_EXPR_LESS=8,
  MRN_EXPR_LESS_EQ=9,
  MRN_EXPR_INT=10,
  MRN_EXPR_TEXT=11
} mrn_expr_type;

typedef struct _mrn_expr
{
  mrn_expr_type type;
  const char *val_string;
  int val_int;
  int n_args;
  struct _mrn_expr *next;
} mrn_expr;

/* macro */
#define MRN_MALLOC(size) malloc(size)
#define MRN_FREE(ptr) free(ptr)

#define MRN_HANDLER_NAME(obj_name) (obj_name - 2)
#define MRN_TABLE_NAME(name) (name + 2)

#define MRN_IS_BIT(map,idx) \
  (uint) (((uchar*)map)[(idx)/8] & (1 << ((idx)&7)))
#define MRN_SET_BIT(map,idx) \
  (((uchar*)map)[(idx)/8] |= (1 << ((idx)&7)))
#define MRN_CLEAR_BIT(map,idx) \
  (((uchar*)map)[(idx)/8] &= ~(1 << ((idx)&7)))

/* functions */
int mrn_init();
int mrn_deinit();
void mrn_logger_func(int level, const char *time, const char *title,
		     const char *msg, const char *location, void *func_arg);
int mrn_flush_logs(grn_ctx *ctx);

int mrn_hash_put(grn_ctx *ctx, const char *key, void *value);
int mrn_hash_get(grn_ctx *ctx, const char *key, void **value);
int mrn_hash_remove(grn_ctx *ctx, const char *key);

mrn_info* mrn_init_obj_info(grn_ctx *ctx, uint n_columns);
int mrn_deinit_obj_info(grn_ctx *ctx, mrn_info *info);
int mrn_create(grn_ctx *ctx, mrn_info *info);
int mrn_open(grn_ctx *ctx, mrn_info *info);
int mrn_close(grn_ctx *ctx, mrn_info *info);
int mrn_drop(grn_ctx *ctx, const char *table_name);
int mrn_write_row(grn_ctx *ctx, mrn_record *record);
mrn_record* mrn_init_record(grn_ctx *ctx, mrn_info *info, uchar *bitmap, int size);
int mrn_deinit_record(grn_ctx *ctx, mrn_record *record);
int mrn_rewind_record(grn_ctx *ctx, mrn_record *record);
int mrn_rnd_init(grn_ctx *ctx, mrn_info *info, mrn_expr *expr);
int mrn_rnd_next(grn_ctx *ctx, mrn_record *record);
uint mrn_table_size(grn_ctx *ctx, mrn_info *info);
void mrn_free_expr(mrn_expr *expr);
void mrn_dump_expr(mrn_expr *expr);

/* static variables */
extern grn_hash *mrn_hash;
extern grn_obj *mrn_db, *mrn_lexicon;
extern pthread_mutex_t *mrn_lock, *mrn_lock_hash;
extern const char *mrn_logfile_name;
extern FILE *mrn_logfile;

extern grn_logger_info mrn_logger_info;

#endif /* _driver_h */