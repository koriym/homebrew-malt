# Malt 設定カスタマイズガイド

Malt は `malt.json` に基づいて開発環境をセットアップしますが、生成された設定ファイルをカスタマイズすることで、プロジェクト固有の要件に柔軟に対応できます。このガイドでは、設定のカスタマイズ方法と注意点、具体的な例について説明します。

## カスタマイズの基本

1.  **`malt create` の実行:** まず、`malt create` コマンドを実行して、プロジェクトルートに `malt/` ディレクトリと、その中に `conf`, `logs`, `tmp`, `var` サブディレクトリ、および各種サービスの設定ファイルを生成します。
    *   **`public/` ディレクトリについて:**
        *   もしプロジェクトに `public/` ディレクトリが**存在しない**場合、`malt create` は `public/` を作成し、Malt の基本的なダッシュボードファイル (`index.html`, `index.php` など) をコピーします。これらのファイルは初期確認用であり、**自由に編集・削除してプロジェクトのコンテンツに置き換えてください**。
        *   もしプロジェクトに `public/` ディレクトリが**既に存在している**場合、`malt create` はこのディレクトリには**一切変更を加えません**。既存のファイルがそのまま Web サーバーのドキュメントルートとして使用されます。
2.  **設定ファイルの編集:** Web サーバー (Nginx, Apache) や PHP、MySQL などの挙動をカスタマイズしたい場合は、`malt/conf/` ディレクトリ内に生成された設定ファイル（例: `nginx_80.conf`, `php.ini`, `my_3306.cnf` など）を**直接編集**します。
3.  **`malt start` の実行:** 編集後、`malt start` を実行すると、カスタマイズされた設定でサービスが起動します。

**重要な注意点:**

*   **`malt create` の再実行について:**
    *   `malt/` ディレクトリが**既に存在する場合**、`malt create` コマンドは**何もせずに終了します**。既存の設定が上書きされることはありません。
    *   `malt.json` を変更した後などで設定ファイルを再生成したい場合は、**まず手動で既存の `malt/` ディレクトリを削除（またはリネーム）** し、その後 `malt create` を再実行してください。
    *   **カスタマイズ内容の保持:** 上記の理由から、`malt create` を再実行すると `malt/conf/` 内のカスタマイズ内容は失われます。カスタマイズした設定を保持したい場合は、`malt/conf/` ディレクトリを Git などのバージョン管理下に置くか、再実行前にバックアップを取ることを強く推奨します。

## `malt.json` 変更時の手順

`malt.json` の `dependencies` や `ports` を変更した場合（例: Apache を削除して Nginx を追加）、以下の手順で環境を更新します。

1.  **依存関係の更新:** `malt install` を実行して、新しい依存関係をインストールします。（不要になった依存関係は `brew uninstall` で手動削除が必要な場合があります）
2.  **既存設定の削除:** **手動で `malt/` ディレクトリ全体を削除（またはリネーム）します。**
3.  **設定ファイルの再生成:** `malt create` を実行して、新しい `malt.json` に基づいた設定ファイルを `malt/conf/` 内に生成します。
4.  **（必要な場合）再カスタマイズ:** 以前に適用していたカスタマイズがあれば、新しく生成された設定ファイルに再度適用します。（バージョン管理していれば、差分を確認して適用できます）
5.  **サービス起動:** `malt start` を実行します。

## 設定ファイル内のテンプレート変数

`malt create` によって生成される `malt/conf/` 内の設定ファイルでは、以下のテンプレート変数が自動的に展開されます。カスタマイズ時にもこれらの変数を活用できます。

*   `{{PROJECT_DIR}}`: プロジェクトのルートディレクトリの絶対パス (例: `/Users/akihito/git/my-project`)。`malt.json` が置かれているディレクトリです。
*   `{{MALT_DIR}}`: `malt` ディレクトリの絶対パス (例: `/Users/akihito/git/my-project/malt`)。
*   `{{HOMEBREW_PREFIX}}`: Homebrew のインストールプレフィックス (例: `/opt/homebrew` や `/usr/local`)。
*   `{{PHP_VERSION}}`: `malt.json` の `dependencies` で指定された PHP のバージョン (例: `8.4`)。
*   `{{PORT}}`: (各サービス設定ファイル内で) その設定ファイルが対象とするポート番号。
*   `{{INDEX}}`: (MySQL設定ファイル内で) 同じサービスで複数のポートが設定されている場合に、0から始まるインデックス番号。
*   `{{PHP_EXTENSIONS}}`: (`php.ini` 内で) `malt.json` の `php_extensions` に基づいて生成された `extension=...` または `zend_extension=...` の行。
*   `{{NGINX_INCLUDES}}`: (`nginx_main.conf` 内で) 各ポート用の Nginx 設定ファイル (`nginx_*.conf`) をインクルードするための `include ...;` 行。
*   `{{PHP_LIB_PATH}}`: (Apache設定ファイル内で) Apache 用 PHP モジュール (`libphp.so`) へのパス。

## 具体的なカスタマイズ例

以下に、一般的なカスタマイズ例をいくつか示します。編集対象は `malt/conf/` 内の対応する設定ファイルです。

### Nginx

対象ファイル: `malt/conf/nginx_*.conf`, `malt/conf/nginx_main.conf`

*   **ドキュメントルートの変更:**
    Malt のデフォルト設定では、Web サーバーはプロジェクト直下の `public/` ディレクトリをドキュメントルートとして使用します。これを変更したい場合は、`malt create` 実行後に `malt/conf/nginx_*.conf` (または `malt/conf/httpd_*.conf`) 内の `root` (または `DocumentRoot`) ディレクティブと、関連する `<Directory>` ディレクティブなどを**手動で編集**する必要があります。
    ```nginx
    # Nginx の例 (malt/conf/nginx_*.conf)
    server {
      listen {{PORT}};
      server_name localhost;
      # root "{{PROJECT_DIR}}/public"; # 元の設定
      root "{{PROJECT_DIR}}/path/to/your/webroot"; # 新しいパスに直接変更

      # ... 他の設定 ...
    }
    ```
    ```apache
    # Apache の例 (malt/conf/httpd_*.conf)
    # DocumentRoot "{{PROJECT_DIR}}/public" # 元の設定
    DocumentRoot "{{PROJECT_DIR}}/path/to/your/webroot"
    <Directory "{{PROJECT_DIR}}/path/to/your/webroot"> # Directory ディレクティブも合わせる
      # ...
    </Directory>
    ```

*   **特定の PHP スクリプトをフロントコントローラーにする:**
    シングルページアプリケーション (SPA) や特定のフレームワークで、すべてのリクエストを特定の PHP スクリプト (例: `index.php` 以外) に集約したい場合、`try_files` や `fastcgi_param SCRIPT_FILENAME` を変更します。
    ```nginx
    server {
      # ...
      location / {
        # try_files $uri /index.php?$query_string; # 一般的な例
        try_files $uri /admin.php?$query_string; # admin.php を使う例
      }

      location ~ \.php$ {
          include "{{HOMEBREW_PREFIX}}/etc/nginx/fastcgi_params";
          fastcgi_pass 127.0.0.1:{{PHP_PORT}};
          fastcgi_index index.php;
          # fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name; # 一般的な例
          fastcgi_param SCRIPT_FILENAME {{PROJECT_DIR}}/bootstrap/app.php; # 特定のスクリプトを指定する例
          # ...
      }
      # ...
    }
    ```
    *注意:* 上記はあくまで例です。フレームワークやアプリケーションの要件に合わせて調整してください。`try_files` と `location ~ \.php$` 内の `SCRIPT_FILENAME` のどちらか、または両方の変更が必要になる場合があります。

*   **Basic 認証の追加:**
    特定のパス (例: `/admin`) に Basic 認証を追加する場合。まず `htpasswd` コマンドでパスワードファイルを作成します。
    ```bash
    # 例: malt/conf/.htpasswd ファイルを作成
    htpasswd -c {{MALT_DIR}}/conf/.htpasswd your_username
    ```
    次に `nginx_*.conf` に `location` ブロックを追加します。
    ```nginx
    server {
      # ...
      location /admin {
        auth_basic "Restricted Area";
        auth_basic_user_file {{MALT_DIR}}/conf/.htpasswd;

        # 必要に応じて PHP への fastcgi_pass などを記述
        # try_files $uri /admin/index.php?$query_string;
        # location ~ \.php$ { ... }
      }
      # ...
    }
    ```

### PHP

対象ファイル: `malt/conf/php.ini`, `malt/conf/php-fpm_*.conf`

*   **`php.ini` 設定の変更:**
    メモリ上限、アップロードファイルサイズ、エラー表示レベルなどを変更します。`malt/conf/php.ini` を直接編集します。
    ```ini
    ; memory_limit = 128M ; 元の設定
    memory_limit = 512M

    ; upload_max_filesize = 2M ; 元の設定
    upload_max_filesize = 100M
    post_max_size = 100M ; upload_max_filesize と合わせることが多い

    ; error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT ; 元の設定例
    error_reporting = E_ALL ; 開発中は全てのエラーを表示する例

    ; display_errors = Off ; 元の設定例
    display_errors = On ; 開発中はエラーを画面に表示する例
    ```

*   **Xdebug の有効化/設定 (例):**
    `malt.json` の `php_extensions` に `"xdebug"` が含まれている場合、`malt/conf/php.ini` の末尾に `zend_extension=xdebug.so` が追加されます。さらに詳細な設定を追加できます。
    ```ini
    [xdebug]
    zend_extension=xdebug.so
    xdebug.mode = debug,develop ; develop を追加すると var_dump が見やすくなる
    xdebug.start_with_request = yes ; リクエスト時に常にデバッガを起動
    xdebug.client_host = 127.0.0.1
    xdebug.client_port = 9003 ; IDE の設定に合わせる
    ; xdebug.log = {{MALT_DIR}}/logs/xdebug.log ; 必要に応じてログを有効化
    ```

*   **PHP-FPM プロセス数の調整:**
    高負荷な開発やテストを行う場合、`malt/conf/php-fpm_*.conf` 内のプロセス管理設定を調整できます。
    ```ini
    ; pm = dynamic ; 元の設定例
    ; pm.max_children = 5
    ; pm.start_servers = 2
    ; pm.min_spare_servers = 1
    ; pm.max_spare_servers = 3

    ; 静的にプロセス数を固定する例 (開発用にはあまり推奨されない)
    ; pm = static
    ; pm.max_children = 10
    ```

### MySQL

対象ファイル: `malt/conf/my_*.cnf`

*   **文字コード設定:**
    デフォルトの文字コードを変更する場合。
    ```ini
    [mysqld]
    # character-set-server = utf8mb4 ; 元の設定例
    # collation-server = utf8mb4_unicode_ci

    [client]
    # default-character-set = utf8mb4
    ```
    *注意:* 既にデータベースが存在する場合、文字コードの変更は既存データに影響を与える可能性があります。

*   **バッファサイズ等の調整:**
    パフォーマンスチューニング（開発環境では通常不要ですが）を行う場合。
    ```ini
    [mysqld]
    # key_buffer_size = 16M ; 例
    # innodb_buffer_pool_size = 128M ; 例
    ```

*(他のサービス (Apache, Redis など) の例も後で追加します)*

## 言語別ガイド

Malt は主にバックグラウンドサービス（Webサーバー、データベース、キャッシュ等）や開発ツール（`wget`, `composer` など）の依存関係を管理するためのツールです。特定のプログラミング言語のバージョン管理（例: Ruby の複数バージョン切り替え）は、`rbenv`, `pyenv`, `nvm`, `volta` といった専用のツールで行うのが一般的です。

しかし、Malt の `dependencies` に Homebrew で提供されている言語ランタイム（例: `ruby@3.2`, `go`, `node`）を追加することで、特定のバージョンをプロジェクトの依存関係としてインストールし、利用することは可能です。

以下に、いくつかの言語での Malt の活用例を示します。

### Ruby

*   **インストール:** `malt.json` の `dependencies` に `"ruby@3.2"` のように追加し、`malt install` を実行します。
*   **パス設定:** `malt env` コマンドは、デフォルトでは Ruby のパスを設定しません。インストールされた Ruby を使うには、Homebrew が提供する標準的なシンボリックリンク (`/opt/homebrew/opt/ruby@3.2/bin` など) を直接利用するか、`rbenv` などのバージョン管理ツールと併用します。
*   **Malt の活用:** Rails アプリケーションなどで必要となる MySQL, Redis, Memcached などのバックグラウンドサービスを Malt で管理すると便利です。
*   **`malt.json` 例 (Rails):**
    ```json
    {
      "project_name": "my_rails_app",
      "dependencies": [
        "ruby@3.2",
        "mysql@8.0",
        "redis",
        "imagemagick"
      ],
      "ports": {
        "mysql": [3306],
        "redis": [6379]
      }
    }
    ```
    *注意:* `dependencies` に Ruby を含めるかは任意です。`rbenv` などで管理する場合は不要かもしれません。Rails サーバー (Puma, Unicorn など) は `malt start` では起動しません。通常通り `bin/rails server` などで起動します。

### Go

*   **インストール:** `malt.json` の `dependencies` に `"go"` を追加し、`malt install` を実行します。
*   **パス設定:** `malt env` は Go のパスを設定しません。Homebrew でインストールされた Go を利用します。
*   **Malt の活用:** Go アプリケーション自体は自己完結型バイナリとしてビルドされることが多いですが、アプリケーションが依存するデータベース (MySQL) やキャッシュ (Redis) などの外部サービスを Malt で管理できます。
*   **`malt.json` 例 (Go Web App):**
    ```json
    {
      "project_name": "my_go_app",
      "dependencies": [
        "go",
        "mysql@8.0",
        "redis"
      ],
      "ports": {
        "mysql": [3306],
        "redis": [6379]
      }
    }
    ```
    *注意:* Go アプリケーションは `go run main.go` やビルドしたバイナリを直接実行して起動します。

### Node.js

*   **インストール:** `malt.json` の `dependencies` に `"node"` を追加し、`malt install` を実行します。
*   **パス設定:** `malt env` は Node.js のパスを設定しません。Homebrew でインストールされた Node.js を利用するか、`nvm` や `volta` といったバージョン管理ツールと併用するのが一般的です。`nvm` などを使う場合、`dependencies` に `"node"` を含めない方が良い場合もあります。
*   **Malt の活用:** Node.js アプリケーションが依存するデータベース (MySQL) やキャッシュ (Redis, Memcached) を Malt で管理します。
*   **`malt.json` 例 (Node.js App):**
    ```json
    {
      "project_name": "my_node_app",
      "dependencies": [
        "mysql@8.0",
        "redis"
      ],
      "ports": {
        "mysql": [3306],
        "redis": [6379]
      }
    }
    ```
    *注意:* `dependencies` に Node.js を含めるかは任意です。`nvm` などで管理する場合は不要です。Node.js アプリケーションは `npm start`, `node server.js` などで起動します。

**まとめ:**

Malt は特定の言語に縛られず、Homebrew で管理できるサービスやツールの依存関係をプロジェクトごとに定義・管理するのに役立ちます。言語ランタイム自体の管理は専用ツールと組み合わせるのが効果的ですが、Malt を使って必要なバージョンをインストールすることも可能です。
