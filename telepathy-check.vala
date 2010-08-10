using TelepathyGLib;
void main (string[] args)
{
  var manager = AccountManager.dup ();
  stdout.printf ("got account manager %p\n", manager);
}
