#include <gcutter.h>
#include <glib/gstdio.h>
#include "driver.h"

static gchar *base_directory;
static gchar *tmp_directory;
static grn_ctx *ctx;

void cut_startup()
{
  base_directory = g_get_current_dir();
  tmp_directory = g_build_filename(base_directory, "/tmp", NULL);
  cut_remove_path(tmp_directory, NULL);
  g_mkdir_with_parents(tmp_directory, 0700);
  g_chdir(tmp_directory);
  grn_init();
  grn_ctx_init(ctx,0);
}

void cut_shutdown()
{
  grn_ctx_fin(ctx);
  grn_fin();
  g_chdir(base_directory);
  g_free(tmp_directory);
}

void test_mrn_init()
{
  mrn_db = NULL;
  mrn_hash = NULL;
  mrn_lexicon = NULL;

  cut_assert_equal_int(0, mrn_init());
  cut_assert_not_null(mrn_db);
  cut_assert_not_null(mrn_hash);
  cut_assert_not_null(mrn_lexicon);
}