module Translation exposing
  ( Language (..)
  , TranslationId (..)
  , translate
  )

type alias TranslationSet =
  { english : String
  , japanese : String
  }

type TranslationId
  = I18n_Go_to_search
    | I18n_Show_index
    | I18n_Add_files_to_database
    | I18n_Search
    | I18n_page
    | I18n_Ask_delete
    | I18n_title
    | I18n_file_path
    | I18n_summary
    | I18n_published_at
    | I18n_created_at
    | I18n_Confirm_delete
    | I18n_Update
    | I18n_Quit

type Language
  = English
  | Japanese

translate : Language -> TranslationId -> String
translate lang trans =
  let
    translationSet =
      case trans of
        I18n_Go_to_search ->
          TranslationSet "Go to search mode" "検索モードへ"
        I18n_Show_index ->
          TranslationSet "Show index" "一覧を表示"
        I18n_Add_files_to_database ->
          TranslationSet "Add files to database" "ファイルを追加する"
        I18n_Search ->
          TranslationSet "Search" "検索"
        I18n_page ->
          TranslationSet "page" "ページへ"
        I18n_Ask_delete ->
          TranslationSet "Delete this document" "削除"
        I18n_Confirm_delete ->
          TranslationSet "Are you sure?" "削除を実行しますか？"
        I18n_title ->
          TranslationSet "Title" "題名"
        I18n_file_path ->
          TranslationSet "File path" "ファイルパス"
        I18n_summary ->
          TranslationSet "Summary" "概要"
        I18n_published_at ->
          TranslationSet "Published at" "出版日"
        I18n_created_at ->
          TranslationSet "Created at" "作成日"
        I18n_Update ->
          TranslationSet "Update" "更新"
        I18n_Quit ->
          TranslationSet "Quit" "終了"
  in
    case lang of
      English ->
        .english translationSet
      Japanese ->
        .japanese translationSet

