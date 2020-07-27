---
title: Countdown problem in Rust
date: 2020-07-27
tags: ["functional programming", "rust", haskell]
categories: ["Programming"]
published: true
---

The countdown problem was presented in a paper by Graham Hutton with a simple
and elegant solution in Haskell. See the paper [here](http://www.cs.nott.ac.uk/~pszgmh/countdown.pdf).
In this post I'll implement the same solution in Rust and see how it looks compared to
the original Haskell solution.

## What is the problem
From the paper:

> Countdown is a popular quiz programme on British television that includes a
  numbers game that we shall refer to as the countdown problem. The essence of
  the problem is as follows: given a sequence of source numbers and a single target
  number, attempt to construct an arithmetic expression using each of the source
  numbers at most once, and such that the result of evaluating the expression is the
  target number. The given numbers are restricted to being non-zero naturals, as are
  the intermediate results during evaluation of the expression.

For eg. Given the numbers `[1, 3, 7, 10, 25, 50]` and target `765`, one solution would
be `(1 + 50) ∗ (25 − 10)`.

## Implementation
In the paper, an initial solution is presented which is then optimized. In this post
we will directly implement the final solution.

First we need a way to represent the supported operations. A sum type is ideal for this
and in Rust we can use `enum` for it:


<table >
<tr>
<td> Haskell </td>
<td> Rust </td>
</tr>
<tr>
<td style="vertical-align:top">

```haskell
data Op
  = Add 
  | Sub 
  | Mul 
  | Div
```

</td>
<td>

```rust
#[derive(Copy, Clone)]
enum Op {
  Add,
  Sub,
  Mul,
  Div
}
```

</td>
</tr>
</table


The definitions looks very similar in both languages, though syntax is different. In Rust we also need to derive traits which
allows us to freely [copy](https://doc.rust-lang.org/std/marker/trait.Copy.html) values of the type in the later program.

Next, we need to define an expression - which is either a number, or two sub-expressions
combined with an operator.

<table>
<tr>
<td> Haskell </td>
<td> Rust </td>
</tr>
<tr>
<td style="vertical-align:top">

```haskell
data Expr
  = Val Int
  | App Op Expr Expr
```

</td>
<td>

```rust
type Int = i64;

#[derive(Clone)]
enum Expr {
  Val(Int),
  App(Op, Rc<Expr>, Rc<Expr>)
}
```

</td>
</tr>
</table

First I added a type alias for `Int` to keep the code similar to Haskell. We start to see differences - in Rust we cannot define nested
references directly. We could use smart pointer like [Box](https://doc.rust-lang.org/std/boxed/struct.Box.html) or
[Rc](https://doc.rust-lang.org/std/rc/struct.Rc.html).
In our case we go with `Rc` since there will be shared sub expressions and reference counted object
performs better in that case.

Next, the paper defines some utility functions: to check if an expr is valid and also to apply
an expression and get its result:

<table>
<tr>
<td> Haskell </td>
<td> Rust </td>
</tr>
<tr>
<td style="vertical-align:top">

```haskell
valid :: Op -> Int -> Int -> Bool
valid Add x y = x <= y
valid Sub x y = x > y
valid Mul x y 
  = x /= 1 
  && y /= 1 
  && x <= y
valid Div x y 
  = y /= 1 
  && x `mod` y == 0

apply :: Op -> Int -> Int -> Int
apply Add x y = x + y
apply Sub x y = x - y
apply Mul x y = x * y
apply Div x y = x `div` y
```

</td>
<td>

```rust
fn valid(op: &Op, x: Int, y: Int) -> bool {
  match op {
    Add => x <= y,
    Sub => x > y,
    Mul => x != 1 && y != 1 && x <= y,
    Div => y > 1 && ((x % y) == 0),
  }
}

fn apply(op: &Op, x: Int, y: Int) -> Int {
  match op {
    Add => x + y,
    Sub => x - y,
    Mul => x * y,
    Div => x / y,
  }
}
```

</td>
</tr>
</table

Apart from syntax, no major change. We can do pattern matching in Rust similar to
Haskell. However, we always need to think about lifetime of variables - here I chose to
work with reference of `Op` instead of `Op` directly. It will be clear why that is better
as we look at other functions that calls this.

Now we get into the core logic of implementation. We need a way to split a list at all possible
points. For eg. `[1, 2, 3]` to `([1], [2, 3]) and ([1, 2], [3])`.

<table>
<tr>
<td> Haskell </td>
<td> Rust </td>
</tr>
<tr>
<td>

```haskell
split        :: [a] -> [([a], [a])]
split []     = [([], [])]
split (x:xs) = ([], x:xs) : [(x:ls, rs)
               | (ls,rs) <- split xs]

ne         :: ([a], [b]) -> Bool
ne (xs,ys) = not (null xs || null ys)

nesplit :: [a] -> [([a], [a])]
nesplit = filter ne . split

```

</td>
<td style="vertical-align:top">

```rust
fn split<T>(ns: &[T])
  -> Vec<(&[T], &[T])> {
  (1..ns.len())
    .map(|i| ns.split_at(i))
    .collect()
}
```

</td>
</tr>
</table

The main difference in the Rust version is the absense of list comprehensions - that 
syntactic sugar is not available, but it possible to achieve something similar using macros.

For eg, using the [cute](https://crates.io/crates/cute) crate, we can rewrite the `split` function as follows:

```rust
fn split<T>(ns: &[T]) -> Vec<(&[T], &[T])> {
  c![ns.split_at(i), for i in 1..ns.len()]
}
```

While this is concise, I'll stick with what we can do with standard Rust in this post.

Next we need a function that returns the list of all permutations of all subsequences of a list.
In the paper it is called `subbags` and uses predefined functions that returns permutations etc.
We use the `permutations` function in the [itertools](https://crates.io/crates/itertools) crate in Rust for simplicity:


<table>
<tr>
<td> Haskell </td>
<td> Rust </td>
</tr>
<tr>
<td>

```haskell
subbags :: [a] ->  [[a ]]
subbags xs = [zs | ys <- subs xs,
                   zs <- perms ys]

-- subs and perms defined elsewhere
```

</td>
<td>

```rust
fn sub_bags<T: Clone>(xs: Vec<T>)
  -> Vec<Vec<T>> {
  (0..xs.len() + 1)
    .flat_map(|i|
      xs.iter().cloned().permutations(i))
    .collect()
}
```

</td>
</tr>
</table

With all the utility functions in place, we are ready to implement the logic for the countdown problem.
The idea is to consider all valid expressions and sub results and combine them to see if we can get the
intended result.


<table>
<tr>
<td> Haskell </td>
<td> Rust </td>
</tr>
<tr>
<td style="vertical-align:top">

```haskell
combine :: Result -> Result 
           -> [Result]
combine (l,x) (r,y)
  = [(App o l r, apply o x y)
      | o <- ops, valid o x y]
```

</td>
<td>

```rust
fn combine((l, x): &Result, (r, y): &Result)
  -> Vec<Result> {
  [Add, Sub, Mul, Div].iter()
    .filter(|op| valid(op, *x, *y))
    .map(|op|
      (App(*op,
           Rc::new(l.clone()),
           Rc::new(r.clone())),
      apply(op, *x, *y)))
    .collect()
}

```

</td>
</tr>
</table


The main difference in Rust has to do with ownership again. To create an `App` we need
to create a new `Rc` for the sub expressions (lines 7 and 8).

Finally the function that ties everything together:

<table>
<tr>
<td> Haskell </td>
<td> Rust </td>
</tr>
<tr>
<td style="vertical-align:top">

```haskell
results :: [Int] -> [Result]
results []  = []
results [n] = [(Val n,n) | n > 0]
results ns
  = [res | (ls,rs) <- nesplit ns
         , lx  <- results ls
         , ry  <- results rs
         , res <- combine lx ry]

solutions :: [Int] -> Int -> [Expr]
solutions ns n
  = [e | ns' <- subbags ns
       , (e,m) <- results ns'
       , m == n]
```

</td>
<td>

```rust
fn results(ns: &[Int]) -> Vec<Result> {
  match ns {
    [] => vec!(),
    [n] => vec!((Val(*n), *n)),
    _ => _results(ns),
  }
}

fn _results(ns: &[Int]) -> Vec<Result> {
  split(ns).iter()
    .flat_map(|(ls, rs)| results(ls).into_iter()
      .flat_map(move |lx| results(rs).into_iter()
        .flat_map(move |ry| combine(&lx, &ry))))
    .collect()
}

pub fn solutions(ns: Vec<Int>, n: Int)
  -> Vec<Expr> {
  sub_bags(ns).iter()
    .flat_map(|b| {
        results(&b).into_iter()
          .filter(|(_, m)| *m == n)
          .map(|(e, _)| e)
          .collect::<Vec<Expr>>()
    })
    .collect()
}
```

</td>
</tr>
</table

That's it. This is  the complete implementation. You can checkout the complete runnable code
[here](https://github.com/amitdev/count_down).

### Sidenote - adding parallelism
Since our code is written in a functional way it is trivial to make parts of it parallel. 
By using the [rayon](https://crates.io/crates/rayon) crate and just making two [minor](https://github.com/amitdev/count_down/commit/1516ce5ea24bf7c6e01d0afa1807b6d1b74ee57b) changes:

* `sub_bags(ns).iter()` --> `sub_bags(ns).par_iter()`
* `Rc` --> `Arc`

this reduces the execution time from *~370ms* to *~70ms* for the above example.

## Summary
Rust is a fairly expressive language and using the functional style is
quite natural. Ownership and lifetimes do get in the way sometimes,
but it is a price worth paying considering the runtime benefits.
Also the compiler error messages are really helpful and guides you to
the right solution.


