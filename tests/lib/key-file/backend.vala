public class KfTest.Backend
{
  private string key_file_name;

  public void set_up (string key_file_contents)
    {
      int fd;

      /* Create a temporary file */
      try
        {
          fd = FileUtils.open_tmp ("folks-kf-test-XXXXXX",
              out this.key_file_name);
        }
      catch (FileError e)
        {
          error ("Error opening temporary file: %s", e.message);
        }

      /* Populate it with the given content */
      IOChannel channel = new IOChannel.unix_new (fd);
      try
        {
          channel.write_chars ((char[]) key_file_contents, null);
        }
      catch (ConvertError e)
        {
          error ("Error converting for writing to temporary file '%s': %s\n%s",
              this.key_file_name, e.message, key_file_contents);
        }
      catch (IOChannelError e)
        {
          error ("Error writing to temporary file '%s': %s", this.key_file_name,
              e.message);
        }

      try
        {
          channel.shutdown (true);
        }
      catch (IOChannelError e) {}
      FileUtils.close (fd);

      /* Set the environment variable for the key file path to the temporary
       * file, causing the key-file backend to use it next time it's loaded */
      Environment.set_variable ("FOLKS_BACKEND_KEY_FILE_PATH",
          this.key_file_name, true);
    }

  public void tear_down ()
    {
      /* Remove the temporary file */
      if (this.key_file_name != null)
        FileUtils.remove (this.key_file_name);
      this.key_file_name = null;
    }
}
