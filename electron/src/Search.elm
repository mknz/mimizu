module Search exposing (..)

import Http
import Json.Decode exposing (int, string, float, bool, nullable, map, map2, map3, map4, map5, map6, field, at, list, Decoder)

import Models exposing (Config, SearchResult, SearchResultRow, IndexResult, IndexResultRow, ResultMessage)
import Messages exposing (Msg(..))


-- JSON decoders

searchResponseDecoder : Decoder SearchResult
searchResponseDecoder =
  let
    rowDecoder =
      map5 SearchResultRow (field "title" string) (field "file_path" string) (field "parent_file_path" string) (field "page" int) (field "highlighted_body" string)
  in
    map3 SearchResult (at ["rows"] <| list rowDecoder) (at ["n_hits"] <| int) (at ["total_pages"] <| int)

indexResultDecoder : Decoder IndexResult
indexResultDecoder =
  let
    rowDecoder =
      map6 IndexResultRow (field "title" string) (field "file_path" string) (field "summary" string) (field "created_at" string) (field "gid" string) (field "published_at" string)
  in
    map3 IndexResult (at ["rows"] <| list rowDecoder) (at ["n_docs"] <| int) (at ["total_pages"] <| int)

messageDecoder : Decoder ResultMessage
messageDecoder =
  at ["message"] <| string

progressDecoder : Decoder String
progressDecoder =
  at ["message"] <| string

configDecoder : Decoder Config
configDecoder =
  map5 Config (field "data_dir" string)
              (field "pdf_dir" string)
              (field "txt_dir" string)
              (field "mode" string)
              (field "locale" string)

-- HTTP

search : String -> Int -> String -> Int -> Cmd Msg
search query numResultPage sortField reverse =
  let
      url =
        "http://localhost:8000/search?q=" ++ query ++ "&sort_field=" ++ sortField
          ++ "&reverse=" ++ (toString reverse)
          ++ "&result-page=" ++ (toString numResultPage)
  in
      Http.send NewSearchResult (Http.get url searchResponseDecoder)

getIndex : String -> Int -> Int -> Cmd Msg
getIndex sortField numResultPage reverse =
  let
      url =
        "http://localhost:8000/sorted-index?field=" ++ sortField
          ++ "&reverse=" ++ (toString reverse)
          ++ "&result-page=" ++ (toString numResultPage)
  in
      Http.send NewIndexResult (Http.get url indexResultDecoder)

deleteDocument : String -> Cmd Msg
deleteDocument gid =
  let
      url =
        "http://localhost:8000/delete?gid=" ++ gid
  in
      Http.send DeleteResult (Http.get url messageDecoder)

getProgress : Cmd Msg
getProgress =
  let
      url =
        "http://localhost:8000/progress"
  in
      Http.send GetProgress (Http.get url progressDecoder)

updateDocument : IndexResultRow -> String -> Cmd Msg
updateDocument row newTitle =
  let
      url =
        "http://localhost:8000/update-document?" ++ "primary-key=" ++ row.file_path ++ "&field=" ++ "title" ++ "&value=" ++ newTitle
  in
      Http.send GetUpdateResult (Http.get url messageDecoder)

getConfig : Cmd Msg
getConfig =
  let
      url =
        "http://localhost:8000/config"
  in
      Http.send GetConfigResult (Http.get url configDecoder)
