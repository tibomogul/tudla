FROM  --platform=${TARGETARCH} ubuntu:24.04
RUN touch /var/mail/ubuntu && chown ubuntu /var/mail/ubuntu && userdel -r ubuntu

# Add PostgreSQL APT repository for version 18
RUN apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  ca-certificates \
  gnupg \
  curl \
  lsb-release \
  && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-keyring.gpg \
  && echo "deb [signed-by=/usr/share/keyrings/postgresql-keyring.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list

RUN apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  build-essential \
  ca-certificates-java \
  cron \
  ffmpeg \
  fonts-liberation \
  git \
  jq \
  libasound2t64 \
  libatk-bridge2.0-0 \
  libatk1.0-0 \
  libc6 \
  libcairo2\
  libcups2 \
  libdbus-1-3 \
  libexpat1 \
  libfaketime \
  libffi-dev \
  libfontconfig1 \
  libgbm1 \
  libgcc1 \
  libglib2.0-0 \
  libgtk-3-0t64 \
  libnspr4 \
  libnss3 \
  libpango-1.0-0 \
  libpangocairo-1.0-0 \
  libpq-dev \
  libreadline-dev \
  libsqlite3-dev \
  libssl-dev \
  libstdc++6 \
  libvips \
  libx11-6 \
  libx11-xcb1 \
  libxcb1 \
  libxcomposite1 \
  libxcursor1 \
  libxdamage1 \
  libxext6 \
  libxfixes3 \
  libxi6 \
  libxrandr2 \
  libxrender1 \
  libxss1 \
  libxtst6 \
  libyaml-dev \
  locales \
  openjdk-11-jre \
  openssh-client \
  pkg-config \
  poppler-data \
  poppler-utils \
  postgresql-client-18 \
  redis \
  ruby-dev \
  sudo \
  tzdata \
  vim-tiny \
  watchman \
  wget \
  xdg-utils \
  zip \
  zlib1g-dev

# https://github.com/jekyll/jekyll/issues/4268#issuecomment-167406574
RUN dpkg-reconfigure locales && \
  locale-gen C.UTF-8 && \
  /usr/sbin/update-locale LANG=C.UTF-8

# Install needed default locale for Makefly
RUN echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen && \
  locale-gen

# Set default locale for the environment
ENV LC_ALL=C.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Use bash as the default shell, and specify a login shell so that .profile is
# sourced when the shell starts
SHELL ["/bin/bash", "-l", "-c"]

# Provide argument or runtime environment variable
ARG build_timezone=Etc/Universal
ENV TZ=$build_timezone

ARG RAILS_ENV=production
ENV RAILS_ENV=${RAILS_ENV}

# Make sure you define build_docker_uid and build_docker_gid to match the user IDs used on your system,
# so that your volume mappings work with your user
ARG build_user_name=user
ENV USER_NAME=$build_user_name
ARG build_docker_uid
RUN test -n "$build_docker_uid" || (echo "build_docker_uid  not set" && false)
ARG build_docker_gid
RUN test -n "$build_docker_gid" || (echo "build_docker_gid  not set" && false)
RUN test -n "$(getent group $build_docker_gid)" || groupadd -g $build_docker_gid $USER_NAME
RUN useradd $USER_NAME -u $build_docker_uid -g $build_docker_gid --create-home --shell /bin/bash
RUN if [ "$RAILS_ENV" = "production" ]; then \
      echo "Skipping sudo"; \
    else \
      mkdir -p /etc/sudoers.d && \
      echo "$USER_NAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USER_NAME && \
      chmod 0440 /etc/sudoers.d/$USER_NAME; \
    fi

USER ${USER_NAME}
WORKDIR /home/$USER_NAME

ARG build_node_version=20.16.0
ENV NODE_VERSION=$build_node_version
ARG NVM_DIR=/home/${USER_NAME}/.nvm
ARG build_nvm_install_version=v0.40.0
ENV NVM_INSTALL_VERSION=$build_nvm_install_version

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_INSTALL_VERSION/install.sh | bash

# We need to source nvm.sh as the installer copies sourcing to .bashrc
RUN . "$NVM_DIR/nvm.sh" \
  && nvm install ${NODE_VERSION} \
  && nvm use v${NODE_VERSION} \
  && nvm alias default v${NODE_VERSION}

# Add this to .profile instead of .bashrc so that its used when bash loads
RUN echo 'PATH=$HOME/.nvm/versions/node/v${NODE_VERSION}/bin/:$PATH' \
  >> /home/${USER_NAME}/.profile

ARG build_ruby_version=3.3.4
ENV RUBY_VERSION=$build_ruby_version

RUN git clone https://github.com/rbenv/rbenv.git /home/${USER_NAME}/.rbenv
RUN git clone https://github.com/rbenv/ruby-build.git /home/${USER_NAME}/.rbenv/plugins/ruby-build

# Add this to .profile instead of .bashrc so that its used when bash loads
RUN echo 'PATH=$HOME/.rbenv/plugins/ruby-build/bin:$HOME/.rbenv/bin:$PATH' \
  >> /home/${USER_NAME}/.profile
RUN echo 'eval "$($HOME/.rbenv/bin/rbenv init -)"' >> /home/${USER_NAME}/.profile

# No need to source .bashrc or .profile here, as its loaded by bash
RUN rbenv install ${RUBY_VERSION} \
  && rbenv global ${RUBY_VERSION}

RUN echo 'gem: --no-document' >> /home/${USER_NAME}/.gemrc

# enable libfaketime
# Add the FAKETIME settings in the .env file
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/faketime/libfaketime.so.1
# RUN echo 'LD_PRELOAD=/usr/lib/x86_64-linux-gnu/faketime/libfaketime.so.1' \
#   >> /home/${USER_NAME}/.bashrc

ENV APP_DIR=app

RUN mkdir /home/$USER_NAME/${APP_DIR}
WORKDIR /home/$USER_NAME/${APP_DIR}

RUN mkdir -p /home/${USER_NAME}/.ssh/
RUN ssh-keyscan github.com >> /home/${USER_NAME}/.ssh/known_hosts
RUN chmod 644 /home/${USER_NAME}/.ssh/known_hosts
RUN echo "Host github.com\n\tStrictHostKeyChecking no\n" >> /home/${USER_NAME}/.ssh/config
RUN chmod 600 /home/${USER_NAME}/.ssh/config

# Install application utility gems
RUN gem install foreman mailcatcher

# Install application utility node packages
# RUN source "/home/${USER_NAME}/.nvm/nvm.sh" \
#   && npm install -g pagedjs-cli

# Install application-specific gems
COPY --chown=${USER_NAME}:${USER_NAME} Gemfile Gemfile.lock ./
RUN gem install bundler -v 2.5.1 \
  && bundle install

RUN if [ "$RAILS_ENV" = "production" ]; then \
      bundle exec bootsnap precompile --gemfile; \
    else \
      echo "Skipping bootsnap precompile 1/3"; \
    fi

# Install application-specific node packages
# COPY --chown=${USER_NAME}:${USER_NAME} package.json package-lock.json ./
# RUN source "/home/${USER_NAME}/.nvm/nvm.sh" \
#   && npm install

  # Copy application code
COPY --chown=${USER_NAME}:${USER_NAME}  . .

RUN if [ "$RAILS_ENV" = "production" ]; then \
      bundle exec bootsnap precompile app/ lib/; \
    else \
      echo "Skipping bootsnap precompile 2/3"; \
    fi

RUN if [ "$RAILS_ENV" = "production" ]; then \
      SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile; \
    else \
      echo "Skipping bootsnap precompile 3/3"; \
    fi

# Entrypoint prepares the database.
# Call the entrypoint of the base image first
# ENTRYPOINT ["./bin/docker-entrypoint"]

# mailcatcher
EXPOSE 1080

# rails server
EXPOSE 3000

# Sleep, we exec into the container for interactive development
CMD ["sleep", "infinity"]
