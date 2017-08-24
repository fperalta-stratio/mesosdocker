#!/usr/bin/env bash

CURRDIR=`cd $(dirname $0); pwd`
cd "$CURRDIR"

for master in master-1 master-2 master-3; do
	export leader="$master"

	export response=`curl -ksI "http://"$leader":5050/master/state-summary" -w "%{response_code}" | tail -1`
	if [[ "$response" == "200" ]]; then
		break;
	fi
done

export redirect1=`curl -ksI -w "%{redirect_url}" "https://$leader/login?firstUser=false"| tail -n1`

export response2=`curl -ksI -w "%{redirect_url}" "$redirect1" | strings`

export cookies=`echo "$response2" | grep --color=never -oP "(?<=^Set-Cookie: ).*" | tr "\n" ";" `
export redirect2=`echo "$response2" |tail -n1`

export response3=`curl -kv -H "Cookie: $cookies" "$redirect2" 2>&1 | strings `

export cookies=`echo "$response3" | grep --color=never -oP "(?<=Cookie: ).*" | tr "\n" ";" `
export ltValue=`echo "$response3" | xmllint --html -xpath "/html//input[@type='hidden' and  @name='lt']/@value" - 2>/dev/null  | grep -oP '(?<=")[^"]*'`
export executionValue=`echo "$response3" | xmllint --html -xpath "/html//input[@type='hidden' and  @name='execution']/@value" - 2>/dev/null  | grep -oP '(?<=")[^"]*'`
export eventIdValue=`echo "$response3" | xmllint --html -xpath "/html//input[@type='hidden' and  @name='_eventId']/@value" - 2>/dev/null  | grep -oP '(?<=")[^"]*'`

export  token=`curl -kvL -POST "$redirect2" \
	-H "Cookie: $cookies" \
	--data-urlencode lt=$ltValue \
	--data-urlencode _eventId="$eventIdValue" \
	--data-urlencode execution="$executionValue" \
	--data-urlencode submit=LOGIN \
	--data-urlencode username=$EOS_USER_SIMPLE \
	--data-urlencode password=$EOS_PASSWORD 2>&1 | strings | grep --color=never -oP '(?<=dcos-acs-auth-cookie=)[^;]+'`

sed -i -r "s/dcos_acs_token = \"[^\"]*\"/dcos_acs_token = \"$token\"/g" $DCOS_CONFIG
# dcos config set core.dcos_acs_token $token >&2
