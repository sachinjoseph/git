# This function uses a trick to manipulate the interactive add to use color:
# the `want_color()` function special-cases the situation where a pager was
# spawned and Git now wants to output colored text: to detect that situation,
# the environment variable `GIT_PAGER_IN_USE` is set. However, color is
# suppressed despite that environment variable if the `TERM` variable
# indicates a dumb terminal, so we set that variable, too.

force_color () {
	env GIT_PAGER_IN_USE=true TERM=vt100 "$@"
}

test_expect_success 'different prompts for mode change/deleted' '
	git reset --hard &&
	>file &&
	>deleted &&
	git add --chmod=+x file deleted &&
	echo changed >file &&
	rm deleted &&
	test_write_lines n n n |
	git -c core.filemode=true add -p >actual &&
	sed -n "s/^\(Stage .*?\).*/\1/p" actual >actual.filtered &&
	cat >expect <<-\EOF &&
	Stage deletion [y,n,q,a,d,?]?
	Stage mode change [y,n,q,a,d,j,J,g,/,?]?
	Stage this hunk [y,n,q,a,d,K,g,/,e,?]?
	EOF
	test_cmp expect actual.filtered
'

test_expect_success 'correct message when there is nothing to do' '
	git reset --hard &&
	git add -p 2>err &&
	test_i18ngrep "No changes" err &&
	printf "\\0123" >binary &&
	git add binary &&
	printf "\\0abc" >binary &&
	git add -p 2>err &&
	test_i18ngrep "Only binary files changed" err
'

test_expect_success 'goto hunk' '
	test_when_finished "git reset" &&
	tr _ " " >expect <<-EOF &&
	Stage this hunk [y,n,q,a,d,K,g,/,e,?]? + 1:  -1,2 +1,3          +15
	_ 2:  -2,4 +3,8          +21
	go to which hunk? @@ -1,2 +1,3 @@
	_10
	+15
	_20
	Stage this hunk [y,n,q,a,d,j,J,g,/,e,?]?_
	EOF
	test_write_lines s y g 1 | git add -p >actual &&
	tail -n 7 <actual >actual.trimmed &&
	test_cmp expect actual.trimmed
'

test_expect_success 'navigate to hunk via regex' '
	test_when_finished "git reset" &&
	tr _ " " >expect <<-EOF &&
	Stage this hunk [y,n,q,a,d,K,g,/,e,?]? @@ -1,2 +1,3 @@
	_10
	+15
	_20
	Stage this hunk [y,n,q,a,d,j,J,g,/,e,?]?_
	EOF
	test_write_lines s y /1,2 | git add -p >actual &&
	tail -n 5 <actual >actual.trimmed &&
	test_cmp expect actual.trimmed
'

test_expect_failure 'edit, adding lines to the first hunk' '
	test_write_lines 10 11 20 30 40 50 51 60 >test &&
	git reset &&
	tr _ " " >patch <<-EOF &&
	@@ -1,5 +1,6 @@
	_10
	+11
	+12
	_20
	+21
	+22
	_30
	EOF
	# test sequence is s(plit), e(dit), n(o)
	# q n q q is there to make sure we exit at the end.
	printf "%s\n" s e n   q n q q |
	EDITOR=./fake_editor.sh git add -p 2>error &&
	test_must_be_empty error &&
	git diff --cached >actual &&
	grep "^+22" actual
'
