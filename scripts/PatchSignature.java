import java.io.*;
import java.nio.file.*;
import java.security.*;
import java.security.cert.CertificateFactory;
import java.util.Base64;

class PatchSignature {
    public static void main(String[] args) throws Exception {
        if (args[0].equals("public")) {
            try (InputStream in = Files.newInputStream(Path.of(args[1]))) {
                byte[] key = CertificateFactory.getInstance("X.509").generateCertificate(in).getPublicKey().getEncoded();
                System.out.println("-----BEGIN PUBLIC KEY-----");
                System.out.println(Base64.getMimeEncoder(64, new byte[] {10}).encodeToString(key));
                System.out.println("-----END PUBLIC KEY-----");
            }
            return;
        }
        char[] password = System.getenv("ROX_PATCH_STORE_PASSWORD").toCharArray();
        try {
            KeyStore store = KeyStore.getInstance(new File(System.getenv("ROX_PATCH_STORE_PATH")), password);
            PrivateKey key = (PrivateKey) store.getKey(System.getenv("ROX_PATCH_STORE_ALIAS"), password);
            Signature signature = Signature.getInstance("SHA256withRSA");
            signature.initSign(key);
            signature.update(Files.readAllBytes(Path.of(args[1])));
            System.out.println(Base64.getEncoder().encodeToString(signature.sign()));
        } finally {
            java.util.Arrays.fill(password, '\0');
        }
    }
}
