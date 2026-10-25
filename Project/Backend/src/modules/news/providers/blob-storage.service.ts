import {
  Injectable,
  InternalServerErrorException,
} from '@nestjs/common';
import {
  BlobServiceClient,
  BlobSASPermissions,
  generateBlobSASQueryParameters,
  StorageSharedKeyCredential,
  SASProtocol,
} from '@azure/storage-blob';

@Injectable()
export class BlobStorageService {
  private readonly containerName =
    process.env.AZURE_STORAGE_CONTAINER_NAME || 'news-audio';

  private getConnectionString(): string {
    const connectionString = process.env.AZURE_STORAGE_CONNECTION_STRING;

    if (!connectionString) {
      throw new InternalServerErrorException(
        'Azure Blob connection string is missing',
      );
    }

    return connectionString;
  }

  private getBlobServiceClient(): BlobServiceClient {
    return BlobServiceClient.fromConnectionString(this.getConnectionString());
  }

  private parseConnectionString(connectionString: string) {
    const parts = connectionString.split(';');
    const map: Record<string, string> = {};

    for (const part of parts) {
      const idx = part.indexOf('=');
      if (idx > 0) {
        const key = part.substring(0, idx);
        const value = part.substring(idx + 1);
        map[key] = value;
      }
    }

    return {
      accountName: map['AccountName'],
      accountKey: map['AccountKey'],
    };
  }

  async uploadAudio(buffer: Buffer, blobName: string): Promise<string> {
    try {
      const blobServiceClient = this.getBlobServiceClient();
      const containerClient = blobServiceClient.getContainerClient(
        this.containerName,
      );

      await containerClient.createIfNotExists();

      const blockBlobClient = containerClient.getBlockBlobClient(blobName);

      await blockBlobClient.uploadData(buffer, {
        blobHTTPHeaders: {
          blobContentType: 'audio/mpeg',
        },
      });

      return blockBlobClient.url;
    } catch (error: any) {
      console.error('BLOB UPLOAD ERROR =>', error);
      console.error('BLOB UPLOAD ERROR CODE =>', error?.code);
      console.error('BLOB UPLOAD ERROR STATUS =>', error?.statusCode);
      throw error;
    }
  }

  async generateReadSasUrl(
    blobUrl: string,
    expiresInMinutes = 30,
  ): Promise<string> {
    const connectionString = this.getConnectionString();
    const { accountName, accountKey } =
      this.parseConnectionString(connectionString);

    if (!accountName || !accountKey) {
      throw new InternalServerErrorException(
        'Could not parse storage account credentials',
      );
    }

    const credential = new StorageSharedKeyCredential(
      accountName,
      accountKey,
    );

    const url = new URL(blobUrl);
    const pathParts = url.pathname.split('/').filter(Boolean);

    if (pathParts.length < 2) {
      throw new InternalServerErrorException('Invalid blob URL');
    }

    const containerName = pathParts[0];
    const blobName = pathParts.slice(1).join('/');

    const startsOn = new Date(Date.now() - 5 * 60 * 1000);
    const expiresOn = new Date(
      Date.now() + expiresInMinutes * 60 * 1000,
    );

    const sas = generateBlobSASQueryParameters(
      {
        containerName,
        blobName,
        permissions: BlobSASPermissions.parse('r'),
        startsOn,
        expiresOn,
        protocol: SASProtocol.Https,
      },
      credential,
    ).toString();

    return `${url.origin}/${containerName}/${blobName}?${sas}`;
  }
}
