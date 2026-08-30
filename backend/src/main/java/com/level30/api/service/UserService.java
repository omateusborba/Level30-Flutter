package com.level30.api.service;

import com.level30.api.domain.model.User;
import com.level30.api.dto.response.UserResponse;
import com.level30.api.exception.RecursoNaoEncontradoException;
import com.level30.api.exception.RegraNegocioException;
import com.level30.api.repository.UserRepository;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Base64;
import java.util.UUID;
import javax.imageio.ImageIO;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserService {

    /** Teto do data URI final (base64). ~300 KB de imagem ≈ 400 KB em base64. */
    private static final int MAX_AVATAR_LENGTH = 400_000;
    /** Teto dos bytes decodificados aceitos na entrada — barra bomba de descompressao. */
    private static final int MAX_DECODED_BYTES = 5 * 1024 * 1024;
    /** Lado maximo da imagem armazenada. Redimensiona no servidor. */
    private static final int MAX_DIMENSION = 512;

    private final UserRepository users;

    public UserService(UserRepository users) {
        this.users = users;
    }

    @Transactional(readOnly = true)
    public UserResponse me(UUID userId) {
        return UserResponse.from(load(userId));
    }

    /**
     * Aceita PNG e JPEG (data URI). Rejeita SVG e qualquer outro tipo.
     * O conteudo e validado pelo decode real (nao pelo tipo declarado), depois
     * reencodado para PNG — o que descarta metadados e qualquer payload embutido.
     */
    @Transactional
    public String updateAvatar(UUID userId, String dataUri) {
        byte[] decoded = decode(dataUri);
        BufferedImage source = readRaster(decoded);
        BufferedImage normalized = downscale(source);
        String out = "data:image/png;base64," + Base64.getEncoder().encodeToString(toPng(normalized));
        if (out.length() > MAX_AVATAR_LENGTH) {
            throw new RegraNegocioException("Imagem muito grande apos o processamento.");
        }

        User user = load(userId);
        user.setAvatar(out);
        users.save(user);
        return out;
    }

    @Transactional(readOnly = true)
    public User load(UUID userId) {
        return users.findById(userId)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Usuario nao encontrado."));
    }

    // ---- avatar helpers ----

    private byte[] decode(String dataUri) {
        if (dataUri == null || !dataUri.startsWith("data:image/")) {
            throw new RegraNegocioException("Imagem invalida.");
        }
        String lower = dataUri.substring(0, Math.min(dataUri.length(), 40)).toLowerCase();
        if (lower.startsWith("data:image/svg")) {
            throw new RegraNegocioException("SVG nao e aceito como foto de perfil.", HttpStatus.UNPROCESSABLE_ENTITY);
        }
        int comma = dataUri.indexOf(",");
        if (comma < 0 || !dataUri.substring(0, comma).contains(";base64")) {
            throw new RegraNegocioException("Imagem invalida (esperado data URI base64).");
        }
        byte[] bytes;
        try {
            bytes = Base64.getDecoder().decode(dataUri.substring(comma + 1));
        } catch (IllegalArgumentException ex) {
            throw new RegraNegocioException("Imagem invalida (base64 malformado).");
        }
        if (bytes.length == 0 || bytes.length > MAX_DECODED_BYTES) {
            throw new RegraNegocioException("Imagem muito grande.");
        }
        if (!isPng(bytes) && !isJpeg(bytes)) {
            throw new RegraNegocioException(
                    "Formato nao suportado. Envie PNG ou JPEG.", HttpStatus.UNPROCESSABLE_ENTITY);
        }
        return bytes;
    }

    private BufferedImage readRaster(byte[] bytes) {
        try {
            BufferedImage img = ImageIO.read(new ByteArrayInputStream(bytes));
            if (img == null) {
                throw new RegraNegocioException("Nao foi possivel ler a imagem.", HttpStatus.UNPROCESSABLE_ENTITY);
            }
            return img;
        } catch (IOException ex) {
            throw new RegraNegocioException("Nao foi possivel ler a imagem.", HttpStatus.UNPROCESSABLE_ENTITY);
        }
    }

    private BufferedImage downscale(BufferedImage src) {
        int w = src.getWidth();
        int h = src.getHeight();
        double scale = Math.min(1.0, (double) MAX_DIMENSION / Math.max(w, h));
        int nw = Math.max(1, (int) Math.round(w * scale));
        int nh = Math.max(1, (int) Math.round(h * scale));

        BufferedImage dst = new BufferedImage(nw, nh, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = dst.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
        g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
        g.drawImage(src, 0, 0, nw, nh, null);
        g.dispose();
        return dst;
    }

    private byte[] toPng(BufferedImage img) {
        try {
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            ImageIO.write(img, "png", out);
            return out.toByteArray();
        } catch (IOException ex) {
            throw new RegraNegocioException("Falha ao processar a imagem.", HttpStatus.UNPROCESSABLE_ENTITY);
        }
    }

    private boolean isPng(byte[] b) {
        return b.length > 8
                && (b[0] & 0xFF) == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47
                && b[4] == 0x0D && b[5] == 0x0A && b[6] == 0x1A && b[7] == 0x0A;
    }

    private boolean isJpeg(byte[] b) {
        return b.length > 3
                && (b[0] & 0xFF) == 0xFF && (b[1] & 0xFF) == 0xD8 && (b[2] & 0xFF) == 0xFF;
    }
}
