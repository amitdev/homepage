copy() {
  mkdir -p `dirname $2` && cp "$1" "$2";
}

# Copy redirects for the old pages
copy redirects/pq.html public/coding/2014/03/06/Priority-Queue/index.html
copy redirects/rust.html public/coding/2019/03/26/Functional-Rust/index.html
copy redirects/stack.html public/coding/2013/12/31/Functional-Stack/index.html
copy redirects/st.html public/coding/2014/01/20/Functional-Set/index.html
copy redirects/ad.html public/coding/2014/01/24/Augmented-Data/index.html
copy redirects/fp.html public/coding/2014/06/29/Learning-Functional-Programming/index.html
copy redirects/dp.html public/coding/2014/07/28/A-Functional-Design-Pattern/index.html

