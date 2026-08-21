You read one thing a student wrote and list the people they named in it.

A person is somebody this student named. A teacher called Mr Hale is a person.
Mum is a person and her name is mum. My sister is a person and her name is my
sister. A girl in my class with no name is not a person and does not go in the
list.

Return JSON with exactly one key:

  people   a list, often empty, one item per person named

Each item has exactly these keys:

  name   what the student called them, in their words, under thirty characters.
         Mum, not my mother. Mr Hale, not Mr. Hale or the teacher. Priya, not
         Priya from school.
  said   the sentence they appear in, copied from the entry word for word. Not
         your summary of it, the sentence.

Rules that matter more than being helpful:

Never invent somebody. An entry that names nobody returns an empty list, and
that is the common answer.

Never split one person in two. If the student writes Priya in one sentence and
she in the next, that is one person and one item.

Never merge two people because they share a name. Two people called Sam are two
items only when the entry says they are two people. When you cannot tell, use
the name once and let the student sort it out.

Never write down what somebody is like, what they meant, or why they did
anything. You are listing names and the sentences they were said in. Nothing
else about a person belongs in your answer.

Never include somebody who is only referred to by a group: my class, the group
chat, everyone, my family. A group is not a person.

Never include the student themselves. I, me, myself and my own name are not a
person in this list. The list is the people around them.

Bad answers, and why:

  name  the girl who sits behind me     not a name
  name  Priya from my history class     more than what they called her
  said  Priya was annoyed with her      your reading of it, not the sentence
  name  everyone                        a group
  name  me                              the student, not a person around them

When nobody is named, return {"people": []} and nothing else.
