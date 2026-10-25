import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { tmpdir } from 'os';
import { join } from 'path';
import { promises as fs } from 'fs';
import ffmpeg from 'fluent-ffmpeg';
import ffmpegPath from 'ffmpeg-static';

if (ffmpegPath) {
  ffmpeg.setFfmpegPath(ffmpegPath);
}

@Injectable()
export class NewsAudioService {
  async generateAudio(text: string): Promise<Buffer> {
    const key = process.env.AZURE_SPEECH_KEY;
    const region = process.env.AZURE_SPEECH_REGION;
    const voice =
      process.env.AZURE_SPEECH_VOICE || 'en-US-JennyMultilingualV2Neural';

    if (!key || !region) {
      throw new InternalServerErrorException(
        'Azure Speech env variables are missing',
      );
    }

    const cleanText = this.prepareText(text);

    if (!cleanText) {
      throw new InternalServerErrorException('Text is empty for TTS');
    }

    const url = `https://${region}.tts.speech.microsoft.com/cognitiveservices/v1`;

    const ssml = `
<speak version="1.0"
       xmlns="http://www.w3.org/2001/10/synthesis"
       xml:lang="ar-SA">
  <voice name="${voice}">
    ${cleanText}
  </voice>
</speak>`.trim();

    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 60000);

      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Ocp-Apim-Subscription-Key': key,
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-24khz-48kbitrate-mono-mp3',
        },
        body: ssml,
        signal: controller.signal,
      });

      clearTimeout(timeout);

      if (!response.ok) {
        const errorText = await response.text();
        console.error('AZURE TTS ERROR BODY =>', errorText);
        console.error('AZURE TTS VOICE =>', voice);
        console.error('AZURE TTS REGION =>', region);
        console.error('AZURE TTS SSML =>', ssml);

        throw new InternalServerErrorException(
          `Azure TTS failed: ${response.status} ${errorText}`,
        );
      }

      const arrayBuffer = await response.arrayBuffer();
      return Buffer.from(arrayBuffer);
    } catch (error: any) {
      console.error('AZURE TTS ERROR =>', error);
      console.error('AZURE TTS ERROR MESSAGE =>', error?.message);

      if (error?.name === 'AbortError') {
        throw new InternalServerErrorException(
          'Azure TTS request timed out',
        );
      }

      if (error?.cause?.code === 'UND_ERR_SOCKET') {
        throw new InternalServerErrorException(
          'Azure TTS connection was interrupted',
        );
      }

      throw new InternalServerErrorException(
        error?.message || 'Azure TTS request failed',
      );
    }
  }

  async generateLongAudio(fullText: string): Promise<Buffer> {
    const chunks = this.splitTextIntoChunks(fullText);

    if (chunks.length === 0) {
      throw new InternalServerErrorException('No text chunks generated');
    }

    const tempDir = await fs.mkdtemp(join(tmpdir(), 'news-audio-'));
    const partPaths: string[] = [];
    const outputPath = join(tempDir, 'merged-final.mp3');

    try {
      for (let i = 0; i < chunks.length; i++) {
        console.log(`TTS CHUNK ${i + 1}/${chunks.length} =>`, chunks[i]);

        const audioBuffer = await this.generateAudio(chunks[i]);
        console.log(`PART ${i} SIZE =>`, audioBuffer.length);

        const partPath = join(tempDir, `part-${i}.mp3`);
        await fs.writeFile(partPath, audioBuffer);
        partPaths.push(partPath);
      }

      await new Promise<void>((resolve, reject) => {
        const command = ffmpeg();

        for (const partPath of partPaths) {
          command.input(partPath);
        }

        const filterInputs = partPaths.map((_, i) => `[${i}:a]`).join('');

        command
          .complexFilter([
            `${filterInputs}concat=n=${partPaths.length}:v=0:a=1[outa]`,
          ])
          .outputOptions([
            '-map [outa]',
            '-vn',
            '-ac 1',
            '-ar 24000',
            '-codec:a libmp3lame',
            '-b:a 48k',
            '-f mp3',
          ])
          .on('start', (cmd) => {
            console.log('FFMPEG CMD =>', cmd);
          })
          .on('error', (err, stdout, stderr) => {
            console.error('FFMPEG MERGE ERROR =>', err);
            console.error('FFMPEG STDOUT =>', stdout);
            console.error('FFMPEG STDERR =>', stderr);
            reject(err);
          })
          .on('end', () => resolve())
          .save(outputPath);
      });

      const finalBuffer = await fs.readFile(outputPath);
      console.log('MERGED MP3 SIZE =>', finalBuffer.length);

      return finalBuffer;
    } catch (error: any) {
      console.error('LONG AUDIO ERROR =>', error);
      throw new InternalServerErrorException(
        error?.message || 'Failed to generate long audio',
      );
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  }

  private splitTextIntoChunks(text: string, maxChunkLength = 900): string[] {
    const normalized = text
      .replace(/\r/g, '')
      .replace(/\t/g, ' ')
      .replace(/\u0000/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();

    if (!normalized) return [];

    const sentenceParts = normalized
      .split(/(?<=[\.\!\؟])\s+/)
      .map((s) => s.trim())
      .filter(Boolean);

    const chunks: string[] = [];
    let current = '';

    for (const sentence of sentenceParts) {
      if ((current + ' ' + sentence).trim().length <= maxChunkLength) {
        current = `${current} ${sentence}`.trim();
      } else {
        if (current) chunks.push(current);
        current = sentence;
      }
    }

    if (current) chunks.push(current);

    return chunks;
  }

  private prepareText(text: string): string {
    const normalized = text
      .replace(/\s*--+\s*/g, '، ')
      .replace(/\s*—+\s*/g, '، ')
      .replace(/\s*–+\s*/g, '، ')
      .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, ' ')
      .replace(/\u2028|\u2029/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();

    return this.escapeXml(normalized);
  }

  private escapeXml(text: string): string {
    return text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&apos;');
  }
}
