set -ex

docker run --rm --pull always quay.io/invidious/youtube-trusted-session-generator > session.txt || :


cat <<EOF > docker-compose.yaml
services:

  invidious:
    image: quay.io/invidious/invidious:latest
    # image: quay.io/invidious/invidious:latest-arm64 # ARM64/AArch64 devices
    restart: unless-stopped
    ports:
      - "127.0.0.1:3000:3000"
    environment:
      # Please read the following file for a comprehensive list of all available
      # configuration options and their associated syntax:
      # https://github.com/iv-org/invidious/blob/master/config/config.example.yml
      INVIDIOUS_CONFIG: |
        db:
          dbname: invidious
          user: kemal
          password: kemal
          host: invidious-db
          port: 5432
        check_tables: true
        signature_server: inv_sig_helper:12999
        # external_port:
        # domain:
        # https_only: false
        # statistics_enabled: false
        log_level: Error
        default_user_preferences:
          region: IN
          autoplay: true
          save_player_pos: true
        hmac_key: "$(openssl rand -hex 32)"
        visitor_data: $(grep visitor_data session.txt | cut -d' ' -f2)
        po_token: $(grep po_token session.txt | cut -d' ' -f2)
    healthcheck:
      test: wget -nv --tries=1 --spider http://127.0.0.1:3000/api/v1/trending || exit 1
      interval: 30s
      timeout: 5s
      retries: 2
    logging:
      options:
        max-size: "1M"
        max-file: "4"
    depends_on:
      - invidious-db

  inv_sig_helper:
    image: quay.io/invidious/inv-sig-helper:latest
    command: ["--tcp", "0.0.0.0:12999"]
    environment:
      - RUST_LOG=info
    restart: unless-stopped
    cap_drop:
      - ALL
    read_only: true
    security_opt:
      - no-new-privileges:true

  invidious-db:
    image: docker.io/library/postgres:14
    restart: unless-stopped
    environment:
      POSTGRES_DB: invidious
      POSTGRES_USER: kemal
      POSTGRES_PASSWORD: kemal
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U kemal -d invidious"]

EOF

docker compose pull

docker compose up
