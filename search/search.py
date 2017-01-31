from whoosh.index import create_in, open_dir
from whoosh.fields import TEXT, DATETIME, NUMERIC, Schema
from whoosh.analysis import NgramTokenizer
from whoosh.qparser import QueryParser, MultifieldParser

import argparse
import os
import datetime
import re
import sys


class Config:
    data_dir = os.environ.get('DATA_DIR')
    if data_dir is None:
        raise ValueError('DATA_DIR is not set in env.')

    if not os.path.exists(data_dir):
        print('Create DATA_DIR: ' + data_dir)
        os.mkdir(data_dir)

    database_dir = os.path.join(data_dir, 'database')
    pdf_dir = os.path.join(data_dir, 'pdf')
    txt_dir = os.path.join(data_dir, 'txt')

    platform = sys.platform


class IndexManager:
    def create_index(self, ngram_min, ngram_max):
        if not os.path.exists(Config.database_dir):
            print('Create DATABASE_DIR: ' + Config.database_dir)
            os.mkdir(Config.database_dir)

        ngram_tokenizer = NgramTokenizer(minsize=ngram_min, maxsize=ngram_max)

        stored_text_field = TEXT(stored=True)
        stored_indexed_text_field = TEXT(stored=True, analyzer=ngram_tokenizer)

        schema = Schema(text_file_path     = stored_text_field,
                        document_file_path = stored_text_field,
                        title              = stored_indexed_text_field,
                        content            = stored_indexed_text_field,
                        page               = NUMERIC(stored=True),
                        memo               = stored_indexed_text_field,
                        created_at         = DATETIME(stored=True))

        ix = create_in(Config.database_dir, schema)
        print('Created db: ' + Config.database_dir)
        ix.close()

    def add_text_file(self, text_file_path, document_file_path, num_page=1):
        if not os.path.exists(Config.database_dir):
            raise ValueError('DB dir does not exist: ' + Config.database_dir)

        _, ext = os.path.splitext(text_file_path)
        if ext != '.txt':
            raise ValueError('Input file is not text file: ' + text_file_path)

        with open(text_file_path, 'r') as f:
            content_text = f.read()

        # set initial title: filename without ext
        title = os.path.splitext(os.path.basename(document_file_path))[0]

        ix = open_dir(Config.database_dir)
        writer = ix.writer()
        writer.add_document(text_file_path     = text_file_path,
                            document_file_path = document_file_path,
                            title              = title,
                            content            = content_text,
                            page               = num_page,
                            memo               = '',
                            created_at         = datetime.datetime.now())
        writer.commit()

        print('Added :' + text_file_path)
        ix.close()

    def add_text_page_file(self, text_file_path):
        """Add database page-wise text file.
        filename format: {DOCUMENT_NAME}_p{NUM_PAGE}.txt
        """
        if not os.path.exists(text_file_path):
            raise ValueError('File does not exist: ' + text_file_path)

        filename = os.path.basename(text_file_path)
        m = re.search(r'(.+)_p(\d+).txt', filename)
        if m is None:
            raise ValueError('Invalid file format: ' + text_file_path)

        doc_filename = m.group(1) + '.pdf'
        doc_file_path = os.path.join(Config.pdf_dir, doc_filename)
        num_page = int(m.group(2))

        if not os.path.exists(doc_file_path):
            raise ValueError('Document file does not exist: ' + doc_file_path)

        self.add_text_file(text_file_path, doc_file_path, num_page)

    def add_dir(self, text_dir_path):
        if not os.path.exists(Config.database_dir):
            raise ValueError('DB dir does not exist: ' + Config.database_dir)

        files = os.listdir(text_dir_path)
        text_file_paths = []
        for file in files:
            _, ext = os.path.splitext(file)
            if ext == '.txt':
                text_file_paths.append(os.path.join(text_dir_path, file))

        if text_file_paths == []:
            raise ValueError('No text files in: ' + text_dir_path)

        for i, path in enumerate(text_file_paths):
            self.add_text_page_file(path)
            # show progress
            print(str(i + 1) + ' / ' + str(len(text_file_paths)))


class Search:
    def __init__(self):
        if not os.path.exists(Config.database_dir):
            raise ValueError('DB dir does not exist: ' + Config.database_dir)
        self.ix = open_dir(Config.database_dir)

    def search(self, query_str):
        with self.ix.searcher() as searcher:
            query = MultifieldParser(['title', 'content'],
                                     self.ix.schema).parse(query_str)
            results = searcher.search(query)
            res_list = []
            for r in results:
                d = {}
                for key in r.keys():  # copy all fields
                    if type(r[key]) == datetime.datetime:
                        d[key] = r[key].isoformat()
                    else:
                        d[key] = r[key]

                # remove garbled characters
                d['highlighted_body'] = self.remove_garble(r.highlights('content'))

                res_list.append(d)
            return res_list

    def remove_garble(self, str):
        """Remove (visually annoying) unicode replacement characters."""
        # TODO: remove with nearby characters (to erase imcomplete words)
        return str.replace('\uFFFD', '')

    def search_print(self, query_str):
        with self.ix.searcher() as searcher:
            query = MultifieldParser(['title', 'content'],
                                     self.ix.schema).parse(query_str)
            results = searcher.search(query)
            for r in results:
                print(r['title'])
                print(r.highlights('content'))
                print('')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--query', default='')
    parser.add_argument('--init', help='Initialize database',
                        action='store_true')
    parser.add_argument('--add-dir', default=None)
    parser.add_argument('--add-files', default=None, nargs='+')
    parser.add_argument('--ngram-min', default=1)
    parser.add_argument('--ngram-max', default=2)
    args = parser.parse_args()

    if args.init:
        im = IndexManager()
        im.create_index(ngram_min=args.ngram_min, ngram_max=args.ngram_max)
        return

    if args.query != '':
        s = Search()
        s.search_print(args.query)
        return

    if args.add_files is not None:
        im = IndexManager()
        for path in args.add_files:
            im.add_text_page_file(path)
        return

    if args.add_dir is not None:
        im = IndexManager()
        im.add_dir(args.add_dir)
        return

    parser.print_help()
    return

if __name__ == '__main__':
    main()
